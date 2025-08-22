package com.sparkage.cart.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sparkage.cart.service.CartService;
import org.junit.jupiter.api.BeforeEach;
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
class CartControllerIT {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private CartService cartService;

    @BeforeEach
    void setup() {
        cartService.clearAll();
    }

    @Test
    void addItem_addsNewAndAggregatesOnSecondCall() throws Exception {
        String body = "{\n" +
                "  \"productId\": 55,\n" +
                "  \"quantity\": 2\n" +
                "}";

        mockMvc.perform(post("/carts/7/items")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(7))
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].productId").value(55))
                .andExpect(jsonPath("$.items[0].quantity").value(2));

        String body2 = "{\n" +
                "  \"productId\": 55,\n" +
                "  \"quantity\": 3\n" +
                "}";

        mockMvc.perform(post("/carts/7/items")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body2))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(7))
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].productId").value(55))
                .andExpect(jsonPath("$.items[0].quantity").value(5));
    }

    @Test
    void addItem_invalid_returns400() throws Exception {
        String invalid = "{\n" +
                "  \"quantity\": 0\n" +
                "}";

        mockMvc.perform(post("/carts/7/items")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(invalid))
                .andExpect(status().isBadRequest());
    }
}
