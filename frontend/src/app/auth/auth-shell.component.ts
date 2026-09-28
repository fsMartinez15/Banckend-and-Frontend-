import { Component } from '@angular/core';
import { BrandComponent } from '../shared/brand.component';
import { MapArtComponent } from '../shared/map-art.component';
@Component({ selector: 'app-auth-shell', imports: [BrandComponent, MapArtComponent], template: `
  <main class="auth-layout">
    <section class="auth-story"><app-brand/><div class="story-copy"><span class="eyebrow">CADA VIAJE, UNA NUEVA HISTORIA</span><h1>Tu ciudad.<br>Tu ritmo.<br><em>Tu próximo viaje.</em></h1><p>Conecta con tu destino y disfruta el camino.<br>Todo comienza con RideMove.</p></div><app-map-art/><div class="story-foot"><span class="dot"></span> Hecho para movernos juntos <span>01 / 03</span></div></section>
    <section class="auth-content"><div class="mobile-brand"><app-brand/></div><ng-content/><footer>RideMove · Movilidad que conecta</footer></section>
  </main>` })
export class AuthShellComponent {}
