import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:siercp/main.dart' as app;

/// Textos localizados de la interfaz (según app_es.arb).
const String txtRegistro = 'Crear cuenta';
const String txtIrRegistro = '¿No tienes cuenta? Regístrate aquí';
const String txtRequerido = 'Requerido';
const String txtEmailInvalido = 'Correo inválido';
const String txtPrivacidad = 'Debes aceptar las Políticas de privacidad';

/// Mensajes de validación propios del formulario de registro.
const String errNombreMin = 'Mínimo 3 caracteres';
const String errNombreMax = 'Máximo 30 caracteres';
const String errDepto = 'Selecciona un departamento';
const String errCiudad = 'Selecciona un municipio';
const String errTel = 'El teléfono debe tener 10 dígitos';
const String errCoinciden = 'Las contraseñas no coinciden';
const String errMayNum = 'Debe incluir mayúsculas y números';

/// Mensaje localizado usado por el validador de contraseña (loc.min6Chars).
/// NOTA: el código (register_screen.dart:397) exige `length < 10` para este
/// mensaje, pero el texto dice "Mínimo 6 caracteres" (inconsistencia del
/// mensaje con la validación real; se documenta, no se altera el código).
const String errMin6 = 'Mínimo 6 caracteres';

const String deptoPrueba = 'Cesar';

/// Datos base válidos (se completan de forma independiente según el test).
const String validNombre = 'Yeimar';
const String validApellido = 'Araujo';
const String validId = '1001234567';
const String validTel = '3001234567';
const String validPass = 'Yeimar12345';

/// La app arranca en /splash y redirige a /login. Desde ahí se navega a
/// /register pulsando el TextButton "¿No tienes cuenta? Regístrate aquí".
Future<void> irAlRegistro(WidgetTester tester) async {
  final enlace = find.text(txtIrRegistro);
  var intentos = 0;
  while (enlace.evaluate().isEmpty && intentos < 60) {
    await tester.pump(const Duration(seconds: 1));
    intentos++;
  }
  expect(enlace, findsOneWidget, reason: 'La pantalla de login no apareció');
  await tester.tap(enlace);
  await tester.pumpAndSettle();
  // Se espera el BOTÓN de registro. "Crear cuenta" también es el título de la
  // pantalla, por lo que ese texto genérico aparece dos veces; se apunta al
  // ElevatedButton para saber que el formulario quedó renderizado.
  final btnRegistro = find.widgetWithText(ElevatedButton, txtRegistro);
  var intentos2 = 0;
  while (btnRegistro.evaluate().isEmpty && intentos2 < 60) {
    await tester.pump(const Duration(seconds: 1));
    intentos2++;
  }
  expect(btnRegistro, findsOneWidget,
      reason: 'La pantalla de registro no apareció');
}

Finder _campo(Finder form, int i) => find.descendant(
      of: form,
      matching: find.byType(TextFormField).at(i),
    );

/// Rellena los campos de texto del Form (0=nombre,1=apellido,2=id,3=tel,
/// 4=correo,5=contraseña,6=confirmar). Los parámetros null no se modifican.
Future<void> llenarFormulario(
  WidgetTester tester, {
  String? nombre,
  String? apellido,
  String? id,
  String? telefono,
  String? email,
  String? password,
  String? confirm,
}) async {
  final form = find.byType(Form);
  if (nombre != null) await tester.enterText(_campo(form, 0), nombre);
  if (apellido != null) await tester.enterText(_campo(form, 1), apellido);
  if (id != null) await tester.enterText(_campo(form, 2), id);
  if (telefono != null) await tester.enterText(_campo(form, 3), telefono);
  if (email != null) await tester.enterText(_campo(form, 4), email);
  if (password != null) await tester.enterText(_campo(form, 5), password);
  if (confirm != null) await tester.enterText(_campo(form, 6), confirm);
  await tester.pump();
}

/// Selecciona la opción [valor] en el i-ésimo DropdownButtonFormField
/// (1 = departamento, 2 = ciudad). Para el tipo de documento (índice 0)
/// usar [seleccionarTipoDoc], ya que sus opciones llevan texto extendido.
Future<void> seleccionarDropdown(
  WidgetTester tester, {
  required int indice,
  required String valor,
}) async {
  final dropdown = find.descendant(
    of: find.byType(Form),
    matching: find.byType(DropdownButtonFormField<String>).at(indice),
  );
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  // El menú del dropdown virtualiza los ítems fuera de vista. Se usan
  // departamentos/municipios de las primeras posiciones (visible sin scroll).
  final opcion = find.text(valor);
  if (opcion.evaluate().isEmpty) {
    // Fallback: desplaza el menú desplegable hasta materializar el ítem.
    await tester.scrollUntilVisible(opcion, 50,
        scrollable: find.byType(Scrollable).last);
  }
  await tester.tap(opcion.last, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// Selecciona el tipo de documento (índice 0). Sus opciones se muestran como
/// "CC — Cédula de Ciudadanía", "CE — Cédula de Extranjería", etc., por lo
/// que se busca el texto completo comenzando por [clave] (p. ej. 'CC — ').
Future<void> seleccionarTipoDoc(
  WidgetTester tester, {
  required String clave,
}) async {
  final dropdown = find.descendant(
    of: find.byType(Form),
    matching: find.byType(DropdownButtonFormField<String>).at(0),
  );
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  final opcion = find.textContaining('$clave —').last;
  await tester.ensureVisible(opcion);
  await tester.pumpAndSettle();
  await tester.tap(opcion, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// Selecciona departamento y la primera ciudad disponible. Usa 'Aguachica'
/// como municipio de prueba (el primer municipio de Cesar, visible sin
/// scroll en el menú desplegable; evita el placeholder).
const String municipioPrueba = 'Aguachica';

/// Selecciona departamento y la primera ciudad disponible.
Future<void> seleccionarDeptoYCiudad(WidgetTester tester,
    {bool conCiudad = true}) async {
  await seleccionarDropdown(tester, indice: 1, valor: deptoPrueba);
  if (conCiudad) {
    final dropdownCiudad = find.descendant(
      of: find.byType(Form),
      matching: find.byType(DropdownButtonFormField<String>).at(2),
    );
    await tester.ensureVisible(dropdownCiudad);
    await tester.pumpAndSettle();
    await tester.tap(dropdownCiudad);
    await tester.pumpAndSettle();
    // Selecciona un municipio real (el primero de Cesar, materializado al
    // abrir el menú, evitando el placeholder).
    final municipio = find.text(municipioPrueba);
    if (municipio.evaluate().isEmpty) {
      fail('El municipio $municipioPrueba no se materializó en el menú');
    }
    await tester.tap(municipio.last, warnIfMissed: false);
    await tester.pumpAndSettle();
  }
}

/// Pulsa "Crear cuenta" SIN marcar el checkbox. Si el formulario es válido,
/// el flujo llega al error de privacidad (no crea usuario). Si un campo es
/// inválido, validate() corta antes de tocar Firebase.
Future<void> someterSinPrivacidad(WidgetTester tester) async {
  final btn = find.widgetWithText(ElevatedButton, txtRegistro);
  await tester.ensureVisible(btn);
  await tester.pumpAndSettle();
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

/// Pulsa "Crear cuenta" CON el checkbox de privacidad ya marcado (registro
/// real). Hace scroll al botón para garantizar que esté visible.
Future<void> someterConPrivacidad(WidgetTester tester) async {
  final btn = find.widgetWithText(ElevatedButton, txtRegistro);
  await tester.ensureVisible(btn);
  await tester.pumpAndSettle();
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

/// Email único (evita colisiones entre ejecuciones).
String emailUnico() =>
    'test_${DateTime.now().millisecondsSinceEpoch}@correo.com';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ========================================================================
  // NOMBRE (casos 1-4)
  // ========================================================================
  testWidgets('C1: nombre válido (3-30) no muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: 'Yeimara', apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errNombreMin), findsNothing);
    expect(find.text(errNombreMax), findsNothing);
    expect(find.text(txtPrivacidad), findsOneWidget);
  });

  testWidgets('C2: nombre < 3 muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: 'Ye', apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errNombreMin), findsWidgets);
  });

  testWidgets('C3: nombre > 30 muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: 'Y' * 31, apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errNombreMax), findsWidgets);
  });

  testWidgets('C4: nombre vacío muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: '', apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(txtRequerido), findsWidgets);
  });

  // ========================================================================
  // APELLIDO (casos 5-8)
  // ========================================================================
  testWidgets('C5: apellido válido no muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: 'Araujito',
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errNombreMin), findsNothing);
    expect(find.text(txtPrivacidad), findsOneWidget);
  });

  testWidgets('C6: apellido < 3 muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: 'Ar',
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errNombreMin), findsWidgets);
  });

  testWidgets('C7: apellido > 30 muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: 'A' * 31,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errNombreMax), findsWidgets);
  });

  testWidgets('C8: apellido vacío muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: '',
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(txtRequerido), findsWidgets);
  });

  // ========================================================================
  // IDENTIFICACIÓN (casos 9-11)
  // ========================================================================
  testWidgets('C9: identificación > 3 dígitos no muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: '1001234567', telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(txtPrivacidad), findsOneWidget);
  });

  testWidgets('C10: identificación <= 3 dígitos muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: '123', telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text('Mínimo 4 caracteres'), findsWidgets);
  });

  // C11: con CC el campo de identificación tiene FilteringTextInputFormatter
  // digitsOnly, por lo que "ABC123" se limpia. Esta prueba documenta el
  // comportamiento del input formatter (la validación que sigue es la de
  // longitud), no de un tipo de dato "no numérico" como tal.
  testWidgets('C11: identificación no numérica (formatter la limpia)',
      (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: 'ABC123', telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    // Tras el formatter el campo queda con '123' (<= 3 dígitos, inválido).
    // Por lo tanto NO debe llegar al error de privacidad.
    expect(find.text(txtPrivacidad), findsNothing,
        reason: 'ABC123 no debe ser una identificación aceptada');
  });

  // ========================================================================
  // TIPO DE DOCUMENTO (casos 12-18)
  // ========================================================================
  for (final (i, tipo) in ['CC', 'CE', 'TI', 'PP', 'NIT', 'DIE'].indexed) {
    testWidgets('C${12 + i}: tipo documento $tipo no muestra error',
        (tester) async {
      app.main();
      await irAlRegistro(tester);
      await llenarFormulario(tester, nombre: validNombre,
          apellido: validApellido,
          id: validId, telefono: validTel,
          email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
          password: validPass, confirm: validPass);
      await seleccionarTipoDoc(tester, clave: tipo);
      await seleccionarDeptoYCiudad(tester);
      await someterSinPrivacidad(tester);
      expect(find.text(txtPrivacidad), findsOneWidget);
    });
  }

  // C18: la UI fuerza un valor por defecto en el dropdown de tipo de
  // documento (arranca en 'CC'), por lo que el estado "sin selección / null"
  // no es alcanzable desde la interfaz. La clase "sin selección" por tanto NO
  // aplica a este control en la implementación real.
  testWidgets('C18: tipo documento sin selección no aplica (default CC)',
      (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre,
        apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    // No se toca el dropdown de tipo de documento: queda en CC por defecto.
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    // No debe solicitar tipo de documento porque siempre hay un valor.
    expect(find.text(txtRequerido).hitTestable(), findsNothing);
    expect(find.text(txtPrivacidad), findsOneWidget);
  });

  // ========================================================================
  // DEPARTAMENTO / CIUDAD (casos 19-22)
  // ========================================================================
  testWidgets('C19: departamento seleccionado no muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errDepto), findsNothing);
    expect(find.text(txtPrivacidad), findsOneWidget);
  });

  testWidgets('C20: departamento sin seleccionar muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    // No elegir departamento.
    await someterSinPrivacidad(tester);
    expect(find.text(errDepto), findsWidgets);
  });

  testWidgets('C21: ciudad seleccionada no muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errCiudad), findsNothing);
    expect(find.text(txtPrivacidad), findsOneWidget);
  });

  testWidgets('C22: ciudad sin seleccionar muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester, conCiudad: false);
    await someterSinPrivacidad(tester);
    expect(find.text(errCiudad), findsWidgets);
  });

  // ========================================================================
  // TELÉFONO (casos 23-26)
  // ========================================================================
  testWidgets('C23: teléfono = 10 dígitos no muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: '3001234567',
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errTel), findsNothing);
    expect(find.text(txtPrivacidad), findsOneWidget);
  });

  testWidgets('C24: teléfono < 10 dígitos muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: '300123456',
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errTel), findsWidgets);
  });

  testWidgets('C25: teléfono > 10 dígitos muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: '30012345678',
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errTel), findsWidgets);
  });

  // C26: el teléfono también usa FilteringTextInputFormatter digitsOnly.
  // La prueba documenta el comportamiento del formatter: "3001a2345b" se
  // limpia y, al no quedar con exactamente 10 dígitos, muestra el error.
  testWidgets('C26: teléfono no numérico (formatter + longitud) muestra error',
      (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId,
        telefono: '3001a2345b', // letras → se limpian a dígitos
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    // Tras limpiar no-dígitos, si el resultado no tiene 10 dígitos → error.
    expect(find.text(txtPrivacidad), findsNothing);
    expect(find.text(errTel), findsWidgets);
  });

  // ========================================================================
  // CORREO (casos 27-29)
  // ========================================================================
  testWidgets('C27: correo válido no muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(txtEmailInvalido), findsNothing);
    expect(find.text(txtPrivacidad), findsOneWidget);
  });

  testWidgets('C28: correo inválido muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'yeimar@correo', // sin extensión de dominio
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(txtEmailInvalido), findsWidgets);
  });

  testWidgets('C29: correo vacío muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel, email: '',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(txtRequerido), findsWidgets);
  });

  // ========================================================================
  // CONTRASEÑA (casos 30-34)
  // ========================================================================
  testWidgets('C30: contraseña válida no muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errMayNum), findsNothing);
    expect(find.text(errMin6), findsNothing);
    expect(find.text(txtPrivacidad), findsOneWidget);
  });

  // C31: "Yeimar1" tiene 7 caracteres (< 10). El validador devuelve
  // loc.min6Chars ("Mínimo 6 caracteres"); aunque el texto alude a "6", la
  // validación real exige mínimo 10 (register_screen.dart:397). Se documenta
  // esa inconsistencia de mensaje sin modificar el comportamiento.
  testWidgets('C31: contraseña < 10 muestra error de longitud', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: 'Yeimar1', confirm: 'Yeimar1');
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errMin6), findsWidgets);
  });

  testWidgets('C32: contraseña sin número muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: 'YeimarABCDE', confirm: 'YeimarABCDE');
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errMayNum), findsWidgets);
  });

  testWidgets('C33: contraseña sin mayúscula muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: 'yeimar12345', confirm: 'yeimar12345');
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errMayNum), findsWidgets);
  });

  testWidgets('C34: contraseña vacía muestra error de longitud', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: '', confirm: '');
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errMin6), findsWidgets);
  });

  // ========================================================================
  // CONFIRMAR CONTRASEÑA (casos 35-37)
  // ========================================================================
  testWidgets('C35: confirmar == contraseña no muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errCoinciden), findsNothing);
    expect(find.text(txtPrivacidad), findsOneWidget);
  });

  testWidgets('C36: confirmar != contraseña muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: 'OtraClave123');
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(errCoinciden), findsWidgets);
  });

  testWidgets('C37: confirmar vacío muestra error', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: '');
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(txtRequerido), findsWidgets);
  });

  // ========================================================================
  // CHECKBOX (caso 38) y REGISTRO EXITOSO (caso 39)
  // ========================================================================
  // C38: se envía el formulario SIN marcar el checkbox. Con todos los campos
  // válidos, el flujo llega al error de privacidad y NO crea un usuario.
  testWidgets('C38: checkbox no marcado muestra error y no crea usuario',
      (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel,
        email: 'nuevo${DateTime.now().millisecondsSinceEpoch}@correo.com',
        password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    await someterSinPrivacidad(tester);
    expect(find.text(txtPrivacidad), findsWidgets);
    // El usuario no se creó: el botón de registro sigue presente.
    expect(find.widgetWithText(ElevatedButton, txtRegistro), findsOneWidget);
  });

  // C39: checkbox marcado + registro real exitoso → crea un usuario real y
  // la app navega fuera del formulario (paso 11 del camino básico).
  testWidgets('C39: registro real exitoso con checkbox marcado', (tester) async {
    app.main();
    await irAlRegistro(tester);
    await llenarFormulario(tester, nombre: validNombre, apellido: validApellido,
        id: validId, telefono: validTel,
        email: emailUnico(), password: validPass, confirm: validPass);
    await seleccionarTipoDoc(tester, clave: 'CC');
    await seleccionarDeptoYCiudad(tester);
    // Marcar el checkbox de privacidad (asegurando que esté visible).
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await someterConPrivacidad(tester);
    // Verificación final robusta: se sale del formulario. Espera activa un
    // tiempo acotado por si la navegación tarda.
    final btnRegistro = find.widgetWithText(ElevatedButton, txtRegistro);
    var salio = false;
    for (var i = 0; i < 20 && !salio; i++) {
      await tester.pump(const Duration(seconds: 1));
      salio = btnRegistro.evaluate().isEmpty;
    }
    expect(salio, isTrue,
        reason: 'Tras un registro exitoso la app debe salir del formulario');
  });
}
