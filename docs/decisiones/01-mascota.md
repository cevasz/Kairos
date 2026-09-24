# 01 · Erizógenes morado

**Pedido (2026-09-23):** la mascota de Kairós es Erizógenes en su versión
violeta ciruela con **monóculo**, la del rediseño B de Cátedra (`b416a89`,
§37 heredado), pero con el rig actual. Su voz pasa del estudio a la vida
diaria.

## El dibujo

- **Se queda el rig, cambia el look.** Poses interpoladas, gestos
  (`MascotBeat`), carrera con zancada, tacto, sueño, ocurrencias
  (`MascotAntic`), `MascotLoader`, `MascotError`, esquina y `MascotStill`
  para los widgets siguen igual. No se volvió al código de `b416a89`.
- **Paleta violeta ciruela** (`color.mascot`): cuerpo `#5B4A6E`, agujas
  `#3E3150` → `#5A4870` → punta `#9C88B4`, tubérculos `#8A77A2`, cejas y boca
  `#231B2C`, pies `#4A3C5C`, latón `#C89B5C`. Del rig actual se conservan el
  volumen (luz arriba a la izquierda, sombra abajo a la derecha) y un contorno
  fino. En oscuro las agujas y los pies se aclaran (`*OnDark`) y aparece la
  luz de borde (`rimLight`): violeta oscuro sobre casi negro perdía la silueta.
- **La cara es la de `b416a89`:** párpado escéptico, cejas de trazo, media
  sonrisa ladeada y barba de tres púas. La barba va en el tono de los
  tubérculos: con el color de las agujas se perdía en la sombra del vientre y
  con uno más claro parecían dientes.
- **Monóculo en lugar de la lámpara.** Agranda el ojo derecho. La cadena cae
  en curva hasta un broche en el vientre y su comba se calcula con un largo
  fijo, así que se interpola sin saltos. Dormido resbala a la mejilla;
  examinando lo sujeta una pata; confundido se cae y cuelga tirante de junto
  al ojo, meciéndose. Un toque lo hace saltar del ojo (`hopMonocleLift`).
- **Lo que decía la llama lo dice el cristal:** su reflejo es vivo en reposo,
  intenso al examinar (con un destello por barrido de la mirada), destella a
  cada zancada al correr (el «sal ya») y se apaga dormido o caído.
- **Ocurrencias:** las seis siguen (cuenco, rollo, reloj de arena, gallo,
  tinaja, sol), pero ya no guarda nada antes: el monóculo no se lo quita. El
  rollo ahora es la lista de pendientes y sale si alguno vence en 7 días; el
  reloj de arena, si hay que salir en menos de 30 min.
- **Sin ánfora.** `MascotVase` queda como un widget vacío (`SizedBox.shrink`)
  para que la bienvenida y el día vacío compilen hasta que se quite de esas
  pantallas; el host `jarrón de fondo`, su tamaño y sus opacidades salen del
  contrato. No se puso nada en su lugar.
- **Pequeño:** a 48 px o menos pierde luces, tubérculos y eslabones; el aro
  engorda y la cadena es un trazo. A 32 px el monóculo se sigue leyendo.

## La voz

- `copy.mascotVoice` habla de salir a tiempo, actividades, saltos, pendientes,
  rachas y días libres. Sigue siendo Diógenes (tinaja, Alejandro, Platón, el
  sol), ahora con monóculo en vez de lámpara. Nunca humilla.
- Las claves y los huecos (`{clase}`, `{salon}`, `{eval}`) se quedan: son
  nombres internos y otras pantallas llaman a esas funciones. Lo que se ve ya
  no dice clase, materia, parcial, nota, profe ni semestre; un test lee el
  contrato y lo comprueba.
- Los consejos de Hoy cambian las evaluaciones por **pendientes con fecha**
  (`pendingProvider`) y dejan de avisar de la fecha límite de cancelación,
  que en Kairós no existe.
