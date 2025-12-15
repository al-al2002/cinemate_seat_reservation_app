class Validators {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required / Kinakailangan ang email';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Invalid email format / Mali ang format ng email';
    }

    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required / Kinakailangan ang password';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters / Dapat 8 characters o higit pa';
    }

    // Check for at least one uppercase letter
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter / Dapat may uppercase letter';
    }

    // Check for at least one lowercase letter
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter / Dapat may lowercase letter';
    }

    // Check for at least one number
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number / Dapat may numero';
    }

    return null;
  }

  // Full name validation
  static String? validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Full name is required / Kinakailangan ang buong pangalan';
    }

    if (value.length < 2) {
      return 'Name is too short / Masyadong maikli ang pangalan';
    }

    if (!value.contains(' ')) {
      return 'Please enter your full name / Ilagay ang buong pangalan';
    }

    return null;
  }

  // Philippine phone number validation (strict - required)
  static String? validatePhilippinePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required / Kinakailangan ang numero';
    }

    // Remove spaces and dashes
    final cleanNumber = value.replaceAll(RegExp(r'[\s-]'), '');

    // Philippine phone number patterns
    // 09XX-XXX-XXXX or +639XX-XXX-XXXX
    final phoneRegex = RegExp(r'^(09|\+639)\d{9}$');

    if (!phoneRegex.hasMatch(cleanNumber)) {
      return 'Invalid PH phone number / Mali ang format ng numero (e.g., 0917-123-4567)';
    }

    return null;
  }

  // Philippine phone number validation (optional)
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Phone number is optional
    }

    // Remove spaces and dashes
    final cleanNumber = value.replaceAll(RegExp(r'[\s-]'), '');

    // Philippine phone number patterns
    // 09XX-XXX-XXXX or +639XX-XXX-XXXX
    final phoneRegex = RegExp(r'^(09|\+639)\d{9}$');

    if (!phoneRegex.hasMatch(cleanNumber)) {
      return 'Invalid PH phone number / Mali ang format ng numero (e.g., 0917-123-4567)';
    }

    return null;
  }

  // Confirm password validation
  static String? validateConfirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password / Kumpirmahin ang password';
    }

    if (value != password) {
      return 'Passwords do not match / Hindi tugma ang mga password';
    }

    return null;
  }

  // Generic required field validation
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required / Kinakailangan ang $fieldName';
    }
    return null;
  }

  // Number validation
  static String? validateNumber(String? value, {double? min, double? max}) {
    if (value == null || value.isEmpty) {
      return 'This field is required / Kinakailangan ang field na ito';
    }

    final number = double.tryParse(value);
    if (number == null) {
      return 'Please enter a valid number / Maglagay ng valid na numero';
    }

    if (min != null && number < min) {
      return 'Value must be at least $min';
    }

    if (max != null && number > max) {
      return 'Value must not exceed $max';
    }

    return null;
  }
}
