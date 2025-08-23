package com.sparkage.order.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sparkage.order.model.Order;
import com.sparkage.order.service.OrderRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class OrderControllerIT {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private ObjectMapper objectMapper;

    @BeforeEach
    void setup() {
        orderRepository.deleteAll();
    }

    @Test
    void createOrder_persists_and_returns201() throws Exception {
        String json = "{" +
                "\"userId\":101," +
                "\"cartId\":202," +
                "\"paymentInfo\":\"MASTERCARD\"," +
                "\"shippingAddress\":\"10 Downing St\"" +
                "}";

        mockMvc.perform(post("/orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isCreated())
                .andExpect(header().exists("Location"))
                .andExpect(jsonPath("$.id").exists())
                .andExpect(jsonPath("$.userId").value(101))
                .andExpect(jsonPath("$.cartId").value(202))
                .andExpect(jsonPath("$.paymentInfo").value("MASTERCARD"))
                .andExpect(jsonPath("$.shippingAddress").value("10 Downing St"))
                .andExpect(jsonPath("$.status").value("PENDING"));

        assertThat(orderRepository.count()).isEqualTo(1);
        Order saved = orderRepository.findAll().get(0);
        assertThat(saved.getUserId()).isEqualTo(101L);
        assertThat(saved.getCartId()).isEqualTo(202L);
        assertThat(saved.getStatus()).isEqualTo("PENDING");
    }

    @Test
    void createOrder_validationError_returns400_and_doesNotPersist() throws Exception {
        String invalid = "{" +
                "\"userId\":null," +
                "\"cartId\":null," +
                "\"paymentInfo\":\"\"," +
                "\"shippingAddress\":\"\"" +
                "}";

        mockMvc.perform(post("/orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(invalid))
                .andExpect(status().isBadRequest());

        assertThat(orderRepository.count()).isEqualTo(0);
    }
}
