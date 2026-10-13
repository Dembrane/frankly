const assert = require('node:assert/strict')
const { test } = require('node:test')

const {
    buildCsp,
    cloudinaryEnabled,
} = require('../js/content-security-policy')

test('allows Cloudinary by default', () => {
    const csp = buildCsp('abc')
    assert.match(csp, /connect-src[^;]*https:\/\/api\.cloudinary\.com/)
    assert.match(csp, /img-src[^;]*https:\/\/res\.cloudinary\.com/)
    assert.match(csp, /media-src[^;]*https:\/\/res\.cloudinary\.com/)
    assert.match(csp, /'nonce-abc'/)
})

test('omits every Cloudinary host when disabled', () => {
    const csp = buildCsp('abc', { cloudinary: false })
    assert.doesNotMatch(csp, /cloudinary/)
    assert.match(csp, /media-src 'self' blob: https:\/\/\*\.mux\.com/)
})

test('reads app.cloudinary_enabled from runtime config', () => {
    assert.equal(cloudinaryEnabled(), true)
    assert.equal(cloudinaryEnabled({}), true)
    assert.equal(cloudinaryEnabled({ cloudinary_enabled: 'true' }), true)
    assert.equal(cloudinaryEnabled({ cloudinary_enabled: ' FALSE ' }), false)
    assert.equal(cloudinaryEnabled({ cloudinary_enabled: false }), false)
})
