package co.ridemove.domain;

public record CheckoutLink(String url, String reference, long amount_in_cents, String currency) {}
