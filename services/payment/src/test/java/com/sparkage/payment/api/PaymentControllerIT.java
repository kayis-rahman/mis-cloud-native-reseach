package com.sparkage.payment.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class PaymentControllerIT {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void process_payment_success_returnsApproved() throws Exception {
        String json = "{" +
                "\"orderId\": 1001," +
                "\"paymentMethod\": \"CARD\"," +
                "\"amount\": 49.99," +
                "\"paymentDetails\": \"tok_test_123\"" +
                "}";

        mockMvc.perform(post("/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"))
                .andExpect(jsonPath("$.transactionId").exists())
                .andExpect(jsonPath("$.orderId").value(1001))
                .andExpect(jsonPath("$.paymentMethod").value("CARD"))
                .andExpect(jsonPath("$.amount").value(49.99))
                .andExpect(jsonPath("$.processedAt").exists());
    }

    @Test
    void process_payment_validation_error_returns400() throws Exception {
        String invalid = "{" +
                "\"orderId\": null," +
                "\"paymentMethod\": \"\"," +
                "\"amount\": -10," +
                "\"paymentDetails\": \"\"" +
                "}";

        mockMvc.perform(post("/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(invalid))
                .andExpect(status().isBadRequest());
    }
}