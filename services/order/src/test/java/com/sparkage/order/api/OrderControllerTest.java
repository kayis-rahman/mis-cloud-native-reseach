package com.sparkage.order.api;

import com.sparkage.order.model.Order;
import com.sparkage.order.service.OrderRepository;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;

import static org.mockito.ArgumentMatchers.any;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(OrderController.class)
class OrderControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private OrderRepository orderRepository;

    @Test
    void createOrder_success_returns201AndBody() throws Exception {
        Order saved = new Order();
        saved.setId(10L);
        saved.setUserId(1L);
        saved.setCartId(2L);
        saved.setPaymentInfo("VISA **** 4242");
        saved.setShippingAddress("221B Baker Street");
        saved.setStatus("PENDING");
        saved.setCreatedAt(Instant.parse("2025-01-01T00:00:00Z"));
        Mockito.when(orderRepository.save(any(Order.class))).thenReturn(saved);

        String json = "{" +
                "\"userId\":1," +
                "\"cartId\":2," +
                "\"paymentInfo\":\"VISA **** 4242\"," +
                "\"shippingAddress\":\"221B Baker Street\"" +
                "}";

        mockMvc.perform(post("/orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", "/orders/10"))
                .andExpect(jsonPath("$.id").value(10))
                .andExpect(jsonPath("$.userId").value(1))
                .andExpect(jsonPath("$.cartId").value(2))
                .andExpect(jsonPath("$.paymentInfo").value("VISA **** 4242"))
                .andExpect(jsonPath("$.shippingAddress").value("221B Baker Street"))
                .andExpect(jsonPath("$.status").value("PENDING"))
                .andExpect(jsonPath("$.createdAt").value("2025-01-01T00:00:00Z"));
    }

    @Test
    void createOrder_validationErrors_returns400() throws Exception {
        // missing required fields and blank strings
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
    }

    @Test
    void createOrder_customStatus_isHonored() throws Exception {
        Order saved = new Order();
        saved.setId(11L);
        saved.setUserId(5L);
        saved.setCartId(7L);
        saved.setPaymentInfo("AMEX");
        saved.setShippingAddress("742 Evergreen Terrace");
        saved.setStatus("CONFIRMED");
        saved.setCreatedAt(Instant.parse("2024-06-01T10:15:30Z"));
        Mockito.when(orderRepository.save(any(Order.class))).thenReturn(saved);

        String json = "{" +
                "\"userId\":5," +
                "\"cartId\":7," +
                "\"paymentInfo\":\"AMEX\"," +
                "\"shippingAddress\":\"742 Evergreen Terrace\"," +
                "\"status\":\"CONFIRMED\"" +
                "}";

        mockMvc.perform(post("/orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", "/orders/11"))
                .andExpect(jsonPath("$.status").value("CONFIRMED"));
    }
}
