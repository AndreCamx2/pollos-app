// Los nombres de los roles coinciden con los de la columna miembros.rol.
enum Rol {
  dueno('Dueño'),
  administrador('Administrador'),
  trabajador('Trabajador');

  const Rol(this.etiqueta);

  final String etiqueta;

  /// Dueño y administrador pueden invitar personas y manejar galpones y lotes.
  bool get administra => this != Rol.trabajador;
}

/// Una granja vista por quien la usa: [rol] es el rol de esa persona en ella.
typedef Granja = ({String id, String nombre, Rol rol});

/// [nombre] es null si la persona todavía no ha entrado a escribirlo.
typedef Miembro = ({String usuarioId, String? nombre, Rol rol});

/// Un código para unirse a la granja que todavía nadie ha usado.
typedef Invitacion = ({String codigo, Rol rol, DateTime venceEn});
