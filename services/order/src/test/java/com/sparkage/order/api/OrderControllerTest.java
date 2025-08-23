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
import java.util.Arrays;
import java.util.Collections;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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

    @Test
    void getOrder_success_returnsDetails() throws Exception {
        Order found = new Order();
        found.setId(77L);
        found.setUserId(9L);
        found.setCartId(8L);
        found.setPaymentInfo("MC");
        found.setShippingAddress("Somewhere");
        found.setStatus("PENDING");
        found.setCreatedAt(Instant.parse("2025-02-02T12:00:00Z"));
        Mockito.when(orderRepository.findById(eq(77L))).thenReturn(Optional.of(found));

        mockMvc.perform(get("/orders/77").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(77))
                .andExpect(jsonPath("$.userId").value(9))
                .andExpect(jsonPath("$.cartId").value(8))
                .andExpect(jsonPath("$.paymentInfo").value("MC"))
                .andExpect(jsonPath("$.shippingAddress").value("Somewhere"))
                .andExpect(jsonPath("$.status").value("PENDING"))
                .andExpect(jsonPath("$.createdAt").value("2025-02-02T12:00:00Z"));
    }

    @Test
    void getOrder_notFound_returns404() throws Exception {
        Mockito.when(orderRepository.findById(eq(999L))).thenReturn(Optional.empty());

        mockMvc.perform(get("/orders/999").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isNotFound());
    }

    @Test
    void getOrdersByUser_returnsList() throws Exception {
        Order o1 = new Order();
        o1.setId(1L);
        o1.setUserId(50L);
        o1.setCartId(100L);
        o1.setPaymentInfo("VISA");
        o1.setShippingAddress("Addr1");
        o1.setStatus("PENDING");
        o1.setCreatedAt(Instant.parse("2025-03-01T00:00:00Z"));

        Order o2 = new Order();
        o2.setId(2L);
        o2.setUserId(50L);
        o2.setCartId(101L);
        o2.setPaymentInfo("MC");
        o2.setShippingAddress("Addr2");
        o2.setStatus("CONFIRMED");
        o2.setCreatedAt(Instant.parse("2025-03-02T00:00:00Z"));

        Mockito.when(orderRepository.findByUserIdOrderByCreatedAtDesc(50L))
                .thenReturn(Arrays.asList(o2, o1));

        mockMvc.perform(get("/orders/user/50").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].id").value(2))
                .andExpect(jsonPath("$[1].id").value(1));
    }

    @Test
    void getOrdersByUser_empty_returnsEmptyArray() throws Exception {
        Mockito.when(orderRepository.findByUserIdOrderByCreatedAtDesc(999L))
                .thenReturn(Collections.emptyList());

        mockMvc.perform(get("/orders/user/999").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(content().json("[]"));
    }

    @Test
    void cancelOrder_success_updatesStatusToCancelled() throws Exception {
        Order existing = new Order();
        existing.setId(55L);
        existing.setUserId(3L);
        existing.setCartId(33L);
        existing.setPaymentInfo("VISA");
        existing.setShippingAddress("Addr");
        existing.setStatus("PENDING");
        existing.setCreatedAt(Instant.parse("2025-03-20T10:00:00Z"));
        Mockito.when(orderRepository.findById(eq(55L))).thenReturn(Optional.of(existing));
        Order cancelled = new Order();
        cancelled.setId(55L);
        cancelled.setUserId(3L);
        cancelled.setCartId(33L);
        cancelled.setPaymentInfo("VISA");
        cancelled.setShippingAddress("Addr");
        cancelled.setStatus("CANCELLED");
        cancelled.setCreatedAt(existing.getCreatedAt());
        Mockito.when(orderRepository.save(any(Order.class))).thenReturn(cancelled);

        mockMvc.perform(post("/orders/55/cancel").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(55))
                .andExpect(jsonPath("$.status").value("CANCELLED"));
    }

    @Test
    void cancelOrder_notFound_returns404() throws Exception {
        Mockito.when(orderRepository.findById(eq(9999L))).thenReturn(Optional.empty());

        mockMvc.perform(post("/orders/9999/cancel").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isNotFound());
    }
}
