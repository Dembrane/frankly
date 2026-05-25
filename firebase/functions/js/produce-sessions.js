const functions = require('firebase-functions')
const admin = require('firebase-admin')
const { regionalFunctions } = require('./function-region')
const fetch = require('node-fetch')
const { notifyDembraneBridge } = require('./dembrane-bridge')

const firestore = admin.firestore()
const storage = admin.storage()
const bucketName = functions.config().agora.storage_bucket_name
const dembraneBridgeUrl = functions.config().dembrane?.bridge_url
const dembraneBridgeToken = functions.config().dembrane?.bridge_token

const artifactLookupAttempts = 6
const artifactLookupDelayMs = 10000
const bridgeSignedUrlExpiration = 24 * 60 * 60 * 1000

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

function getErrorMessage(err) {
    return err instanceof Error ? err.message : String(err)
}

async function listMp4Files({ bucket, gcsPrefix }) {
    const [files] = await bucket.getFiles({ prefix: `${gcsPrefix}/` })
    return files
        .filter((file) => file.name.endsWith('.mp4'))
        .sort((left, right) => left.name.localeCompare(right.name))
}

async function waitForMp4Files({ bucket, gcsPrefix, sessionId }) {
    for (let attempt = 1; attempt <= artifactLookupAttempts; attempt += 1) {
        const mp4Files = await listMp4Files({ bucket, gcsPrefix })
        if (mp4Files.length > 0) {
            return mp4Files
        }

        if (attempt < artifactLookupAttempts) {
            console.log(
                `No MP4 found under ${gcsPrefix}/ for session ${sessionId} on attempt ${attempt}/${artifactLookupAttempts}. Retrying in ${artifactLookupDelayMs}ms`
            )
            await sleep(artifactLookupDelayMs)
        }
    }

    throw new Error(
        `No MP4 found under ${gcsPrefix}/ for session ${sessionId} after ${artifactLookupAttempts} attempts`
    )
}

function buildArtifactUpdates(mp4Files) {
    const updates = {}
    mp4Files.forEach((file, index) => {
        updates[`artifactPaths.complete_mp4_${index}`] = file.name
    })
    return updates
}

// Triggered when a recording session transitions to 'stopped'.
// Locates the MP4 Agora deposited under gcsPrefix and registers its path on
// the session document.
const produceSessions = regionalFunctions().firestore
    .document('recording-sessions/{sessionId}')
    .onUpdate(async (change, context) => {
        const before = change.before.data()
        const after = change.after.data()

        if (before.status === after.status) return null
        if (after.status !== 'stopped') return null

        const sessionId = context.params.sessionId
        const gcsPrefix = after.gcsPrefix
        if (!gcsPrefix) {
            console.warn(`Session ${sessionId} has no gcsPrefix, skipping post-processing`)
            return null
        }

        const bucket = storage.bucket(bucketName)

        try {
            const mp4Files = await waitForMp4Files({
                bucket,
                gcsPrefix,
                sessionId,
            })
            console.log(
                `Found ${
                    mp4Files.length
                } MP4(s) under ${gcsPrefix}/ for session ${sessionId}: ${mp4Files
                    .map((file) => file.name)
                    .join(', ')}`
            )
            await change.after.ref.update(buildArtifactUpdates(mp4Files))
            console.log(`Registered ${mp4Files.length} MP4(s) for session ${sessionId}`)

            await notifyDembraneBridge({
                sessionRef: change.after.ref,
                sessionId,
                sessionData: after,
                mp4Files,
                bridgeUrl: dembraneBridgeUrl,
                bridgeToken: dembraneBridgeToken,
                fetchImpl: fetch,
                fieldValue: admin.firestore.FieldValue,
                signedUrlExpirationMs: bridgeSignedUrlExpiration,
            })

            await change.after.ref.update({
                'postProcessing.lastAttemptAt':
                    admin.firestore.FieldValue.serverTimestamp(),
                'postProcessing.lastCompletedAt':
                    admin.firestore.FieldValue.serverTimestamp(),
                'postProcessing.lastError': admin.firestore.FieldValue.delete(),
            })
        } catch (err) {
            const message = getErrorMessage(err)
            console.error(`Error post-processing session ${sessionId}:`, err)
            try {
                await change.after.ref.update({
                    'postProcessing.lastAttemptAt':
                        admin.firestore.FieldValue.serverTimestamp(),
                    'postProcessing.lastError': message,
                })
            } catch (updateErr) {
                console.error(
                    `Error recording post-processing failure for session ${sessionId}:`,
                    updateErr
                )
            }
            throw err
        }

        return null
    })

module.exports = produceSessions
