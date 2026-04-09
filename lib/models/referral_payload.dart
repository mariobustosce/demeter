class ReferralPayload {
  final String referralCode;
  final int rewardPerReferral;
  final int welcomeBonusForFriend;
  final String shareMessage;
  final String registerHint;
  final int currentBalance;

  const ReferralPayload({
    required this.referralCode,
    required this.rewardPerReferral,
    required this.welcomeBonusForFriend,
    required this.shareMessage,
    required this.registerHint,
    required this.currentBalance,
  });

  factory ReferralPayload.fromJson(Map<String, dynamic> json) {
    return ReferralPayload(
      referralCode: json['referral_code']?.toString() ?? '',
      rewardPerReferral:
          int.tryParse(json['reward_per_referral']?.toString() ?? '0') ?? 0,
      welcomeBonusForFriend:
          int.tryParse(json['welcome_bonus_for_friend']?.toString() ?? '0') ??
          0,
      shareMessage: json['share_message']?.toString() ?? '',
      registerHint: json['register_hint']?.toString() ?? '',
      currentBalance:
          int.tryParse(json['current_balance']?.toString() ?? '0') ?? 0,
    );
  }
}
