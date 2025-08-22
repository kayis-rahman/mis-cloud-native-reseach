package com.sparkage.cart.api;

import com.sparkage.cart.api.dto.AddCartItemRequest;
import com.sparkage.cart.api.dto.CartItemResponse;
import com.sparkage.cart.api.dto.CartResponse;
import com.sparkage.cart.api.dto.UpdateCartItemQuantityRequest;
import com.sparkage.cart.model.Cart;
import com.sparkage.cart.model.CartItem;
import com.sparkage.cart.service.CartService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
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

    @PutMapping(path = "/{userId}/items/{itemId}", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CartResponse> updateItemQuantity(@PathVariable("userId") Long userId,
                                                           @PathVariable("itemId") Long itemId,
                                                           @Valid @RequestBody UpdateCartItemQuantityRequest request) {
        Cart updated = cartService.updateItemQuantity(userId, itemId, request.getQuantity());
        return ResponseEntity.ok(toResponse(updated));
    }

    @DeleteMapping(path = "/{userId}/items/{itemId}")
    public ResponseEntity<CartResponse> removeItem(@PathVariable("userId") Long userId,
                                                   @PathVariable("itemId") Long itemId) {
        Cart updated = cartService.removeItem(userId, itemId);
        return ResponseEntity.ok(toResponse(updated));
    }

    @GetMapping(path = "/{userId}")
    public ResponseEntity<CartResponse> getCart(@PathVariable("userId") Long userId) {
        Cart cart = cartService.getCart(userId);
        return ResponseEntity.ok(toResponse(cart));
    }

    @ExceptionHandler(CartService.NotFoundException.class)
    public ResponseEntity<Void> handleNotFound(CartService.NotFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
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
