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
}
