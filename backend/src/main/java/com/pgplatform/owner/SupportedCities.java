package com.pgplatform.owner;

import com.pgplatform.common.ConflictException;

import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

/** Cities currently supported by the verified property-location flow. */
public final class SupportedCities {
    private static final Map<String, String> CITIES = new LinkedHashMap<>();

    static {
        for (String city : new String[]{
                "Ahmedabad", "Bengaluru", "Bhopal", "Bhubaneswar", "Chandigarh", "Chennai",
                "Coimbatore", "Delhi", "Faridabad", "Ghaziabad", "Gurugram", "Hyderabad",
                "Indore", "Jaipur", "Kochi", "Kolkata", "Lucknow", "Mumbai", "Mysuru",
                "Nagpur", "Nashik", "Noida", "Patna", "Pune", "Secunderabad", "Surat",
                "Thane", "Thiruvananthapuram", "Vadodara", "Vijayawada", "Visakhapatnam"
        }) {
            CITIES.put(key(city), city);
        }
        CITIES.put(key("Bangalore"), "Bengaluru");
        CITIES.put(key("Gurgaon"), "Gurugram");
    }

    private SupportedCities() { }

    public static String requireCanonical(String value) {
        String canonical = value == null ? null : CITIES.get(key(value));
        if (canonical == null) {
            throw new ConflictException("Choose a valid city from the supported city list");
        }
        return canonical;
    }

    private static String key(String value) {
        return value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
    }
}
