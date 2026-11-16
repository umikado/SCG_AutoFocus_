# Third-party notices

T1-1/T1-2 add no third-party runtime packages or models. Foundation and XCTest are toolchain/system modules. Swift 6.0.3 is a development tool (Apache-2.0 with Runtime Library Exception): https://github.com/swiftlang/swift/blob/swift-6.0.3-RELEASE/LICENSE.txt. GitHub Actions uses actions/checkout v4 (MIT) as CI tooling: https://github.com/actions/checkout/blob/v4/LICENSE.

Future dependencies require their full notices before integration.

## T1-3: swift-crypto 3.3.0

SHA-256 uses the Crypto product of https://github.com/apple/swift-crypto at commit f0525da24dc3c6cbb2b6b338b65042bc91cbc4bb (Package.resolved). Apache-2.0; complete upstream license and notice are preserved in docs/licenses/. Its Linux implementation vendors BoringSSL; upstream per-file notices are retained in the dependency source. No additional package dependencies are resolved. The app attribution page must include these notices before distribution.

The vendored BoringSSL revision is dbad745811195c00b729efd0ee0a09b7d9fce1d2, as recorded in swift-crypto's Sources/CCryptoBoringSSL/hash.txt. Its complete upstream license is preserved at docs/licenses/BoringSSL-LICENSE.txt (https://github.com/google/boringssl/blob/dbad745811195c00b729efd0ee0a09b7d9fce1d2/LICENSE).
