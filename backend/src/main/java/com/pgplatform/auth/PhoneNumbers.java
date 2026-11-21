package com.pgplatform.auth;

/** One canonical representation for OTP identities and private owner contacts. */
public final class PhoneNumbers {
    private PhoneNumbers() { }

    public static String normalize(String value) {
        String compact = value == null ? "" : value.replaceAll("[\\s()-]", "");
        if (compact.matches("0[6-9]\\d{9}")) return "+91" + compact.substring(1);
        if (compact.matches("\\d{10}")) return "+91" + compact;
        if (compact.matches("91\\d{10}")) return "+" + compact;
        if (!compact.matches("\\+[1-9]\\d{7,14}")) {
            throw new IllegalArgumentException("Enter a valid mobile number with country code");
        }
        return compact;
    }
}
