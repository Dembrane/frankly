'use strict'

// Content-Security-Policy for the HTML served by ServeIndex.
//
// Cloudinary hosts are allowed unless the deployment sets
// `app.cloudinary_enabled` to "false". Deployments that must keep media and
// visitor traffic away from Cloudinary (for example EU-only deployments) turn
// it off here and leave CLOUDINARY_CLOUD_NAME unset in the client build.

function cloudinaryEnabled(appConfig = {}) {
    const value = appConfig.cloudinary_enabled
    if (typeof value === 'boolean') return value
    if (typeof value !== 'string') return true
    return value.trim().toLowerCase() !== 'false'
}

function buildCsp(nonce, { cloudinary = true } = {}) {
    const cloudinaryHosts = cloudinary
        ? ' https://res.cloudinary.com https://api.cloudinary.com'
        : ''
    const cloudinaryMediaHost = cloudinary ? ' https://res.cloudinary.com' : ''
    const directives = [
        `default-src 'self'`,
        `script-src 'strict-dynamic' 'nonce-${nonce}' 'wasm-unsafe-eval'`,
        `style-src 'self' 'unsafe-inline' https://vjs.zencdn.net`,
        `font-src 'self' data: https://fonts.gstatic.com`,
        // connect-src covers all fetch/XHR/WebSocket calls the Flutter app makes.
        // Add entries here if new backend services are integrated.
        `connect-src 'self'` +
            ` https://*.firebaseio.com wss://*.firebaseio.com` +
            ` https://*.googleapis.com https://*.cloudfunctions.net` +
            ` https://api.agora.io https://*.agora.io wss://*.agora.io:*` +
            ` https://*.sd-rtn.com wss://*.sd-rtn.com:*` +
            ` https://*.twiliocdn.com https://*.twilio.com` +
            ` https://api.mux.com https://stream.mux.com` +
            cloudinaryHosts +
            ` https://player.vimeo.com https://api.segment.io` +
            ` https://api.linkpreview.net https://*.stripe.com` +
            ` https://frankly.org https://fonts.gstatic.com https://www.gstatic.com`,
        `img-src 'self' data: blob: https://firebasestorage.googleapis.com` +
            cloudinaryMediaHost +
            ` https://*.googleusercontent.com` +
            ` https://picsum.photos https://fastly.picsum.photos`,
        `media-src 'self' blob: https://firebasestorage.googleapis.com${cloudinaryMediaHost} https://*.mux.com`,
        `frame-src 'self'` +
            ` https://player.vimeo.com https://*.stripe.com https://*.firebaseapp.com`,
        `worker-src 'self' blob:`,
        `object-src 'none'`,
        `base-uri 'self'`,
        `frame-ancestors 'self'`,
    ]
    return directives.join('; ')
}

module.exports = { buildCsp, cloudinaryEnabled }
