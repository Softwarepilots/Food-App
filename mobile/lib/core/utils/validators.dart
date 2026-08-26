class Validators {
  Validators._();

  static final RegExp _phoneRegex = RegExp(r'^\+?[1-9]\d{7,14}$');

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    if (!_phoneRegex.hasMatch(value.trim())) return 'Enter a valid phone number, e.g. +919876543210';
    return null;
  }

  static String? otp(String? value, {int length = 6}) {
    if (value == null || value.trim().isEmpty) return 'Enter the OTP';
    if (value.trim().length != length || !RegExp(r'^\d+$').hasMatch(value.trim())) {
      return 'Enter the $length-digit OTP';
    }
    return null;
  }

  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? pincode(String? value) {
    if (value == null || value.trim().isEmpty) return 'Pincode is required';
    if (!RegExp(r'^\d{4,10}$').hasMatch(value.trim())) return 'Enter a valid pincode';
    return null;
  }
}
