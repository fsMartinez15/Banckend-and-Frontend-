package co.ridemove.domain;

/** Conductor conectado cercano; posición aproximada y sin identidad. */
public record NearbyDriver(double latitude, double longitude, Integer distance_m) {}
