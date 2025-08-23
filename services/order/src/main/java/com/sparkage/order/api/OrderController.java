package com.sparkage.order.api;

import com.sparkage.order.api.dto.CreateOrderRequest;
import com.sparkage.order.api.dto.OrderResponse;
import com.sparkage.order.model.Order;
import com.sparkage.order.service.OrderRepository;
import jakarta.validation.Valid;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.net.URI;

@RestController
@RequestMapping(path = "/orders")
public class OrderController {

    private final OrderRepository repository;

    public OrderController(OrderRepository repository) {
        this.repository = repository;
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<OrderResponse> createOrder(@Valid @RequestBody CreateOrderRequest request) {
        Order order = new Order();
        order.setUserId(request.getUserId());
        order.setCartId(request.getCartId());
        order.setPaymentInfo(request.getPaymentInfo());
        order.setShippingAddress(request.getShippingAddress());
        if (request.getStatus() != null && !request.getStatus().isBlank()) {
            order.setStatus(request.getStatus());
        }
        Order saved = repository.save(order);
        OrderResponse body = toResponse(saved);
        return ResponseEntity.created(URI.create("/orders/" + saved.getId())).body(body);
    }

    private OrderResponse toResponse(Order o) {
        return new OrderResponse(
                o.getId(),
                o.getUserId(),
                o.getCartId(),
                o.getPaymentInfo(),
                o.getShippingAddress(),
                o.getStatus(),
                o.getCreatedAt()
        );
    }
}
