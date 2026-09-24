import 'package:flutter/services.dart';

import 'tokens.g.dart';

/// Háptica según el contrato. Los tres pesos y, sobre todo, la lista de lo que
/// NUNCA vibra: scroll, navegación entre pestañas y apertura de sheets.
abstract final class Haptics {
  /// `action` es el nombre del contrato, p. ej. `marcarAsistencia`. Se pasa el
  /// nombre y no el peso para que la tabla de tokens siga siendo la autoridad.
  static Future<void> fire(String action) async {
    if (HapticTokens.never.contains(action)) return;
    if (HapticTokens.light.contains(action)) return HapticFeedback.lightImpact();
    if (HapticTokens.medium.contains(action)) return HapticFeedback.mediumImpact();
    if (HapticTokens.heavy.contains(action)) return HapticFeedback.heavyImpact();
    // Una acción sin clasificar no vibra. El silencio es el default seguro.
  }

  /// El «sal ya» vibra una vez por alerta, no una vez por rebuild. Quien llama
  /// tiene que llevar la cuenta; este flag es el recordatorio en el tipo.
  static Future<void> enteredUrgent({required bool alreadyFired}) async {
    if (alreadyFired) return;
    await fire('entrarEstadoSalYa');
  }
}
