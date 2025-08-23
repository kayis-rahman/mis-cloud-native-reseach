package com.sparkage.cart.api;

import com.sparkage.cart.model.Cart;
import com.sparkage.cart.model.CartItem;
import com.sparkage.cart.service.CartService;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Arrays;
import java.util.Collections;

import static org.mockito.ArgumentMatchers.eq;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(CartController.class)
class CartControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private CartService cartService;

    @Test
    void addItem_success_returnsUpdatedCart() throws Exception {
        Cart cart = new Cart(1L);
        cart.setItems(Arrays.asList(new CartItem(10L, 3)));
        Mockito.when(cartService.addItem(eq(1L), eq(10L), eq(3))).thenReturn(cart);

        String json = "{\n" +
                "  \"productId\": 10,\n" +
                "  \"quantity\": 3\n" +
                "}";

        mockMvc.perform(post("/carts/1/items")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.userId").value(1))
                .andExpect(jsonPath("$.items[0].productId").value(10))
                .andExpect(jsonPath("$.items[0].quantity").value(3));
    }

    @Test
    void addItem_validationErrors_returns400() throws Exception {
        String invalid = "{\n" +
                "  \"productId\": null,\n" +
                "  \"quantity\": 0\n" +
                "}";

        mockMvc.perform(post("/carts/1/items")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(invalid))
                .andExpect(status().isBadRequest());
    }

    @Test
    void clearCart_success_returnsEmptyCart() throws Exception {
        Cart empty = new Cart(9L);
        empty.setItems(Collections.emptyList());
        Mockito.when(cartService.clearCart(9L)).thenReturn(empty);

        mockMvc.perform(post("/carts/9/clear"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(9))
                .andExpect(jsonPath("$.items.length()").value(0));
    }

    @Test
    void updateQuantity_success_returnsUpdatedCart() throws Exception {
        Cart cart = new Cart(2L);
        cart.setItems(Arrays.asList(new CartItem(50L, 7)));
        Mockito.when(cartService.updateItemQuantity(eq(2L), eq(50L), eq(7))).thenReturn(cart);

        String body = "{\n  \"quantity\": 7\n}";
        mockMvc.perform(put("/carts/2/items/50").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(2))
                .andExpect(jsonPath("$.items[0].productId").value(50))
                .andExpect(jsonPath("$.items[0].quantity").value(7));
    }

    @Test
    void updateQuantity_validationError_returns400() throws Exception {
        String invalid = "{\n  \"quantity\": 0\n}";
        mockMvc.perform(put("/carts/2/items/50").contentType(MediaType.APPLICATION_JSON).content(invalid))
                .andExpect(status().isBadRequest());
    }

    @Test
    void updateQuantity_notFound_returns404() throws Exception {
        Mockito.when(cartService.updateItemQuantity(eq(3L), eq(99L), eq(5)))
                .thenThrow(new CartService.NotFoundException("not found"));
        String body = "{\n  \"quantity\": 5\n}";
        mockMvc.perform(put("/carts/3/items/99").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isNotFound());
    }

    @Test
    void deleteItem_success_returnsUpdatedCart() throws Exception {
        Cart cart = new Cart(4L);
        cart.setItems(Collections.emptyList());
        Mockito.when(cartService.removeItem(4L, 77L)).thenReturn(cart);
        mockMvc.perform(delete("/carts/4/items/77"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(4))
                .andExpect(jsonPath("$.items.length()").value(0));
    }

    @Test
    void deleteItem_notFound_returns404() throws Exception {
        Mockito.when(cartService.removeItem(4L, 88L)).thenThrow(new CartService.NotFoundException("not found"));
        mockMvc.perform(delete("/carts/4/items/88"))
                .andExpect(status().isNotFound());
    }

    @Test
    void getCart_returnsCartWithItems() throws Exception {
        Cart cart = new Cart(5L);
        cart.setItems(Arrays.asList(new CartItem(99L, 4), new CartItem(100L, 1)));
        Mockito.when(cartService.getCart(5L)).thenReturn(cart);

        mockMvc.perform(get("/carts/5").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.userId").value(5))
                .andExpect(jsonPath("$.items.length()").value(2))
                .andExpect(jsonPath("$.items[0].productId").value(99))
                .andExpect(jsonPath("$.items[0].quantity").value(4))
                .andExpect(jsonPath("$.items[1].productId").value(100))
                .andExpect(jsonPath("$.items[1].quantity").value(1));
    }

    @Test
    void getCart_noCartYet_returnsEmptyList() throws Exception {
        Cart empty = new Cart(8L);
        empty.setItems(Collections.emptyList());
        Mockito.when(cartService.getCart(8L)).thenReturn(empty);

        mockMvc.perform(get("/carts/8").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(8))
                .andExpect(jsonPath("$.items.length()").value(0));
    }
}
