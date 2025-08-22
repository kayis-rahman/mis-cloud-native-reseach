package com.sparkage.cart.service;

import com.sparkage.cart.model.Cart;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class CartServiceTest {

    private CartService cartService;

    @BeforeEach
    void setup() {
        cartService = new CartService();
    }

    @Test
    void addItem_firstTime_createsCartAndAddsItem() {
        Cart cart = cartService.addItem(1L, 100L, 2);
        assertEquals(1L, cart.getUserId());
        assertEquals(1, cart.getItems().size());
        assertEquals(100L, cart.getItems().get(0).getProductId());
        assertEquals(2, cart.getItems().get(0).getQuantity());
    }

    @Test
    void addItem_sameProduct_accumulatesQuantity() {
        cartService.addItem(1L, 100L, 2);
        Cart cart = cartService.addItem(1L, 100L, 3);
        assertEquals(1, cart.getItems().size());
        assertEquals(5, cart.getItems().get(0).getQuantity());
    }

    @Test
    void addItem_invalid_throws() {
        assertThrows(IllegalArgumentException.class, () -> cartService.addItem(null, 1L, 1));
        assertThrows(IllegalArgumentException.class, () -> cartService.addItem(1L, null, 1));
        assertThrows(IllegalArgumentException.class, () -> cartService.addItem(1L, 1L, 0));
    }

    @Test
    void updateItemQuantity_setsExactQuantity_and_validates() {
        cartService.addItem(2L, 10L, 2);
        Cart updated = cartService.updateItemQuantity(2L, 10L, 7);
        assertEquals(7, updated.getItems().get(0).getQuantity());
        assertThrows(IllegalArgumentException.class, () -> cartService.updateItemQuantity(2L, 10L, 0));
    }

    @Test
    void updateItemQuantity_notFound_throws() {
        assertThrows(CartService.NotFoundException.class, () -> cartService.updateItemQuantity(3L, 99L, 1));
        cartService.addItem(3L, 1L, 1);
        assertThrows(CartService.NotFoundException.class, () -> cartService.updateItemQuantity(3L, 99L, 1));
    }

    @Test
    void removeItem_success_and_notFound() {
        cartService.addItem(4L, 55L, 1);
        Cart afterRemove = cartService.removeItem(4L, 55L);
        assertEquals(0, afterRemove.getItems().size());
        assertThrows(CartService.NotFoundException.class, () -> cartService.removeItem(4L, 55L));
    }
}
