import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';

/// Thin wrapper around bmoni_embedded_sdk. This is the ONLY place in the
/// app allowed to touch the SDK — never generate keys or sign messages
/// anywhere else. The private key never leaves the device; only public
/// addresses and signatures cross into ApiClient calls.
class WalletService {
  static void initialize() {
    // 6-digit PIN, required before signMessage/deleteWallet — matches
    // the "PIN-gated signing" requirement in the build brief.
    BmoniEmbeddedSdk.initialize(pinLength: 6, requirePin: true);
  }

  static Future<bool> hasWallet() => BmoniEmbeddedSdk.hasWallet();

  static Future<String?> currentAddress() => BmoniEmbeddedSdk.walletAddress();

  /// Provisions a new on-device EVM owner wallet. Throws
  /// [BmoniSignerException] with [BmoniSignerErrorCode.walletAlreadyExists]
  /// if one already exists on this device — callers should check
  /// [hasWallet] first rather than relying on the exception for control
  /// flow.
  static Future<String> provisionWallet() => BmoniEmbeddedSdk.initWallet();

  static Future<bool> hasPin() => BmoniEmbeddedSdk.hasPin();

  static Future<void> setPin(String pin) => BmoniEmbeddedSdk.setPin(pin);

  /// Signs [message] (the raw text of a BMONI owner-proof challenge) with
  /// EIP-191 `personal_sign`, gated by [pin]. This is the signature that
  /// gets submitted back to the backend as `ownerProofSignature`.
  static Future<String> signChallenge(String message, String pin) =>
      BmoniEmbeddedSdk.signMessage(message, pin: pin);

  /// Signs a pre-computed 32-byte digest directly — no prefix, no
  /// additional hashing. This is what a BMONI transfer proposal's
  /// `signingPayloadHash` (from GET sign-payload) needs: confirmed live
  /// against the sandbox that BMONI wants a raw ECDSA signature over that
  /// exact hash, NOT the EIP-712 hash of the `typedData` object it's
  /// packaged alongside — signing the properly-computed EIP-712 digest
  /// was tested and rejected ("signature does not match your registered
  /// owner address"). See backend/README.md "Phase 3 findings" for the
  /// full story. Do not run `digestHex` through any additional hashing
  /// before calling this.
  static Future<String> signDigest(String digestHex, String pin) =>
      BmoniEmbeddedSdk.signTransactionHash(digestHex, pin: pin);
}
