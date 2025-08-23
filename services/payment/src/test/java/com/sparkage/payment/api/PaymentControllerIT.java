package com.sparkage.payment.api;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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

    @Test
    void get_payment_by_id_returns_details_after_post() throws Exception {
        String json = "{" +
                "\"orderId\": 2002," +
                "\"paymentMethod\": \"WALLET\"," +
                "\"amount\": 19.99," +
                "\"paymentDetails\": \"tok_get_1\"" +
                "}";

        MvcResult result = mockMvc.perform(post("/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode node = objectMapper.readTree(result.getResponse().getContentAsString());
        String paymentId = node.get("transactionId").asText();

        mockMvc.perform(get("/payments/" + paymentId).accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.transactionId").value(paymentId))
                .andExpect(jsonPath("$.orderId").value(2002))
                .andExpect(jsonPath("$.paymentMethod").value("WALLET"))
                .andExpect(jsonPath("$.amount").value(19.99))
                .andExpect(jsonPath("$.status").exists())
                .andExpect(jsonPath("$.processedAt").exists());
    }

    @Test
    void get_unknown_payment_returns404() throws Exception {
        mockMvc.perform(get("/payments/unknown-id"))
                .andExpect(status().isNotFound());
    }
}