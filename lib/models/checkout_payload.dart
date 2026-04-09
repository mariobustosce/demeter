class CheckoutPayload {
  final String preferenceId;
  final String initPoint;
  final String sandboxInitPoint;
  final String publicKey;
  final String externalReference;

  const CheckoutPayload({
    required this.preferenceId,
    required this.initPoint,
    required this.sandboxInitPoint,
    required this.publicKey,
    required this.externalReference,
  });

  factory CheckoutPayload.fromJson(Map<String, dynamic> json) {
    return CheckoutPayload(
      preferenceId: json['preference_id']?.toString() ?? '',
      initPoint: json['init_point']?.toString() ?? '',
      sandboxInitPoint: json['sandbox_init_point']?.toString() ?? '',
      publicKey: json['public_key']?.toString() ?? '',
      externalReference: json['external_reference']?.toString() ?? '',
    );
  }
}
