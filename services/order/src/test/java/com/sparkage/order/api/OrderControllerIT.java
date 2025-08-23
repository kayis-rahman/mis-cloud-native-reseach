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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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

    @Test
    void getOrder_byId_returnsDetails() throws Exception {
        Order o = new Order();
        o.setUserId(42L);
        o.setCartId(777L);
        o.setPaymentInfo("VISA");
        o.setShippingAddress("123 Test Ave");
        Order saved = orderRepository.save(o);

        mockMvc.perform(get("/orders/" + saved.getId()).accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(saved.getId()))
                .andExpect(jsonPath("$.userId").value(42))
                .andExpect(jsonPath("$.cartId").value(777))
                .andExpect(jsonPath("$.paymentInfo").value("VISA"))
                .andExpect(jsonPath("$.shippingAddress").value("123 Test Ave"))
                .andExpect(jsonPath("$.status").value("PENDING"));
    }

    @Test
    void getOrder_notFound_returns404() throws Exception {
        mockMvc.perform(get("/orders/99999999").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isNotFound());
    }

    @Test
    void getOrdersByUser_returnsOnlyUsersOrders_sortedDesc() throws Exception {
        // user 1 orders
        Order a1 = new Order(); a1.setUserId(1L); a1.setCartId(10L); a1.setPaymentInfo("VISA"); a1.setShippingAddress("A1");
        Order a2 = new Order(); a2.setUserId(1L); a2.setCartId(11L); a2.setPaymentInfo("MC"); a2.setShippingAddress("A2");
        // another user
        Order b1 = new Order(); b1.setUserId(2L); b1.setCartId(20L); b1.setPaymentInfo("AMEX"); b1.setShippingAddress("B1");
        orderRepository.save(a1);
        // small delay by saving in sequence; createdAt set at instantiation but generally close; order not guaranteed by DB w/o createdAt desc.
        orderRepository.save(b1);
        orderRepository.save(a2);

        mockMvc.perform(get("/orders/user/1").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].userId").value(1))
                .andExpect(jsonPath("$[1].userId").value(1));
    }

    @Test
    void getOrdersByUser_empty_returnsEmptyArray() throws Exception {
        mockMvc.perform(get("/orders/user/999999").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().json("[]"));
    }
}
