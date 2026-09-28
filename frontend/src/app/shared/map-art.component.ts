import { Component } from '@angular/core';
@Component({ selector: 'app-map-art', template: `
  <svg class="map-art" viewBox="0 0 720 570" fill="none" aria-hidden="true">
    <defs><pattern id="blocks" width="92" height="74" patternUnits="userSpaceOnUse" patternTransform="rotate(-18)"><rect x="8" y="8" width="74" height="56" rx="12" fill="currentColor" opacity=".055"/></pattern></defs>
    <rect width="720" height="570" fill="url(#blocks)"/>
    <path d="M-30 480C90 390 62 310 198 330S370 414 423 228 648 189 771 85" stroke="#b2d9d8" stroke-width="33" opacity=".4"/>
    <path d="M90 580L220 345L133 198L417 62M403 588L351 342L639 207L562-20" stroke="currentColor" stroke-opacity=".1" stroke-width="15"/>
    <path d="M200 382L286 323L260 246L464 168L517 234" stroke="white" stroke-width="19" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M200 382L286 323L260 246L464 168L517 234" stroke="#1957ed" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>
    <circle cx="200" cy="382" r="18" fill="#1957ed" stroke="white" stroke-width="6"/>
    <circle cx="517" cy="234" r="20" fill="#ff7a45" stroke="white" stroke-width="6"/>
    <circle cx="517" cy="234" r="5" fill="white"/>
  </svg>` })
export class MapArtComponent {}
