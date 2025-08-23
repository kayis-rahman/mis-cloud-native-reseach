package com.sparkage.order.api;

import com.sparkage.order.api.dto.CreateOrderRequest;
import com.sparkage.order.api.dto.OrderResponse;
import com.sparkage.order.model.Order;
import com.sparkage.order.service.OrderRepository;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.net.URI;
import java.util.List;
import java.util.stream.Collectors;

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

    @GetMapping(path = "/{orderId}", produces = MediaType.APPLICATION_JSON_VALUE)
    public OrderResponse getOrder(@PathVariable("orderId") Long orderId) {
        Order o = repository.findById(orderId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "order not found"));
        return toResponse(o);
    }

    @GetMapping(path = "/user/{userId}", produces = MediaType.APPLICATION_JSON_VALUE)
    public List<OrderResponse> getOrdersByUser(@PathVariable("userId") Long userId) {
        List<Order> orders = repository.findByUserIdOrderByCreatedAtDesc(userId);
        return orders.stream().map(this::toResponse).collect(Collectors.toList());
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
