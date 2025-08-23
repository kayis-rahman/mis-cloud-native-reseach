package com.sparkage.payment.api;

import com.sparkage.payment.api.dto.PaymentRequest;
import com.sparkage.payment.api.dto.PaymentResponse;
import com.sparkage.payment.service.PaymentProcessorService;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/payments")
public class PaymentController {

    private final PaymentProcessorService processorService;

    public PaymentController() {
        // simple manual wiring to avoid extra configuration
        this.processorService = new PaymentProcessorService();
    }

    // Alternative constructor for testing/DI if needed
    public PaymentController(PaymentProcessorService processorService) {
        this.processorService = processorService;
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public PaymentResponse process(@RequestBody @jakarta.validation.Valid PaymentRequest request) {
        return processorService.process(request);
    }

    @GetMapping(value = "/{paymentId}", produces = MediaType.APPLICATION_JSON_VALUE)
    public PaymentResponse getPayment(@PathVariable("paymentId") String paymentId) {
        return processorService.getById(paymentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "payment not found"));
    }
}
