// La sfera del mappamondo (tela, 144–151): la Terra disegnata, non
// fotografata. Ogni punto del disco torna al suo punto della sfera, e lì si
// sa se è giorno o notte, secondo dove sta il sole adesso: chiaro dove è
// giorno, buio dove è notte, con una striscia di crepuscolo e l'atmosfera sul
// bordo. Le terre sono i puntini, disegnati sopra.
#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uCentro;
uniform float uRaggio;
// Verso est, verso nord e verso chi guarda, dal centro del globo.
uniform vec3 uEst;
uniform vec3 uNord;
uniform vec3 uVerso;
// Il punto della Terra che ha il sole a picco.
uniform vec3 uSole;
uniform vec3 uGiorno;
uniform vec3 uNotte;

out vec4 fragColor;

void main() {
  vec2 p = (FlutterFragCoord().xy - uCentro) / uRaggio;
  p.y = -p.y;
  float d = dot(p, p);
  if (d > 1.0) {
    fragColor = vec4(0.0);
    return;
  }
  float z = sqrt(1.0 - d);
  vec3 w = p.x * uEst + p.y * uNord + z * uVerso;
  float luce = smoothstep(-0.1, 0.12, dot(w, uSole));
  // Più chiaro verso il centro, e sul bordo l'atmosfera, più viva di giorno.
  vec3 colore = mix(uNotte, uGiorno, luce) * (0.7 + 0.3 * z);
  float bordo = pow(1.0 - z, 3.0);
  colore += vec3(0.24, 0.36, 0.88) * bordo * (0.25 + 0.45 * luce);
  fragColor = vec4(colore, 1.0);
}
