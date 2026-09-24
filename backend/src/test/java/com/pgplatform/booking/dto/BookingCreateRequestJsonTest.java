package com.pgplatform.booking.dto;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.pgplatform.booking.BookingType;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class BookingCreateRequestJsonTest {

    private final ObjectMapper objectMapper = new ObjectMapper().findAndRegisterModules();

    @Test
    void acceptsLegacyMobileBookingPayload() throws Exception {
        UUID bedId = UUID.randomUUID();
        LocalDate moveInDate = LocalDate.now().plusDays(1);

        BookingCreateRequest request = objectMapper.readValue("""
                {
                  "bedId": "%s",
                  "moveInDate": "%s"
                }
                """.formatted(bedId, moveInDate), BookingCreateRequest.class);

        assertThat(request.bedId()).isEqualTo(bedId);
        assertThat(request.bookingType()).isEqualTo(BookingType.MONTHLY);
        assertThat(request.checkInDate()).isEqualTo(moveInDate);
        assertThat(request.checkOutDate()).isNull();
    }

    @Test
    void preservesCurrentFlexibleBookingPayload() throws Exception {
        UUID bedId = UUID.randomUUID();
        LocalDate checkInDate = LocalDate.now().plusDays(1);
        LocalDate checkOutDate = checkInDate.plusDays(3);

        BookingCreateRequest request = objectMapper.readValue("""
                {
                  "bedId": "%s",
                  "bookingType": "DAY_WISE",
                  "checkInDate": "%s",
                  "checkOutDate": "%s"
                }
                """.formatted(bedId, checkInDate, checkOutDate), BookingCreateRequest.class);

        assertThat(request.bedId()).isEqualTo(bedId);
        assertThat(request.bookingType()).isEqualTo(BookingType.DAY_WISE);
        assertThat(request.checkInDate()).isEqualTo(checkInDate);
        assertThat(request.checkOutDate()).isEqualTo(checkOutDate);
        assertThat(request.checkOutTime()).hasToString("11:00");
    }
}
