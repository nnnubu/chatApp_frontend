class CheckInput {
  static final RegExp regNickValid = RegExp(r'^[\u4e00-\u9fa5a-zA-Z0-9_-]+$');
  static final RegExp regPwdChinese = RegExp(r'[\u4e00-\u9fa5]');
  static final RegExp regPwdLetter = RegExp(r'[A-Za-z]');
  static final RegExp regPwdDigit = RegExp(r'\d');
  static final RegExp regQQEmail = RegExp(r'^[1-9]\d{4,10}@qq\.com$');
  static final RegExp regCode6 = RegExp(r'^\d{6}$');
  static final RegExp regIntro = RegExp(r"[<>]");

  static String? nickname(String value) {
    if (value.isEmpty) return "昵称不能为空";
    if (value.isEmpty || value.length > 20) return "昵称长度1-20位";
    if (!regNickValid.hasMatch(value)) return "昵称仅支持中文、字母、数字、_、-";
    return null;
  }

  static String? password(String value) {
    if (value.isEmpty) return "请输入密码";
    if (regPwdChinese.hasMatch(value)) return "密码不能包含中文";
    if (value.length < 8 || value.length > 20) return "密码长度为 8-20 位";
    if (!regPwdLetter.hasMatch(value)) return "必须包含字母";
    if (!regPwdDigit.hasMatch(value)) return "必须包含数字";
    if (value.contains(" ")) return "密码不能包含空格";
    return null;
  }

  static String? email(String value) {
    if (value.isEmpty) return "邮箱不能为空";
    if (!regQQEmail.hasMatch(value)) return "请输入正确的邮箱格式(目前仅支持QQ邮箱)";
    return null;
  }

  static String? code(String value) {
    if (value.isEmpty) return "请输入验证码";
    if (!regCode6.hasMatch(value)) return "必须是6位数字";
    return null;
  }

  static String? intro(String value) {
    if (value.length > 100) {
      return "简介不能超过100字";
    }
    if (regIntro.hasMatch(value)) {
      return "简介包含非法字符 < >";
    }
    return null;
  }

  static String? gender(int? value) {
    if (value == null) return "请选择性别";
    if (![0, 1, 2].contains(value)) return "性别参数非法";
    return null;
  }

  static String? birthday(String? value) {
    if (value == null || value.isEmpty) return null;
    DateTime? dt = DateTime.tryParse(value);
    if (dt == null) return "生日格式必须为 yyyy-MM-dd";
    // 限制合理年龄
    final now = DateTime.now();
    final min = DateTime(now.year - 120, now.month, now.day);
    if (dt.isBefore(min) || dt.isAfter(now)) {
      return "生日日期超出合法范围";
    }
    return null;
  }

  static String? verifyMsg(String? value) {
    if (value == null || value.isEmpty) return "请输入验证信息";
    if (value.length > 80) return "验证信息长度不能超过 80";
    return null;
  }
}
