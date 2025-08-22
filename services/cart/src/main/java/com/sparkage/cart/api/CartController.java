package com.sparkage.cart.api;

import com.sparkage.cart.api.dto.AddCartItemRequest;
import com.sparkage.cart.api.dto.CartItemResponse;
import com.sparkage.cart.api.dto.CartResponse;
import com.sparkage.cart.model.Cart;
import com.sparkage.cart.model.CartItem;
import com.sparkage.cart.service.CartService;
import jakarta.validation.Valid;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping(path = "/carts", produces = MediaType.APPLICATION_JSON_VALUE)
public class CartController {

    private final CartService cartService;

    public CartController(CartService cartService) {
        this.cartService = cartService;
    }

    @PostMapping(path = "/{userId}/items", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CartResponse> addItem(@PathVariable("userId") Long userId,
                                                @Valid @RequestBody AddCartItemRequest request) {
        Cart updated = cartService.addItem(userId, request.getProductId(), request.getQuantity());
        return ResponseEntity.ok(toResponse(updated));
    }

    @GetMapping(path = "/{userId}")
    public ResponseEntity<CartResponse> getCart(@PathVariable("userId") Long userId) {
        Cart cart = cartService.getCart(userId);
        return ResponseEntity.ok(toResponse(cart));
    }

    private CartResponse toResponse(Cart cart) {
        List<CartItemResponse> items = cart.getItems().stream()
                .map(this::toItem)
                .collect(Collectors.toList());
        return new CartResponse(cart.getUserId(), items);
    }

    private CartItemResponse toItem(CartItem item) {
        return new CartItemResponse(item.getProductId(), item.getQuantity());
    }
}
