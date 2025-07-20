import { AppDataSource } from "../config/configDb.js";
import Reporte from "../entity/reporte.entity.js";
import User from "../entity/user.entity.js";

// Crear un nuevo reporte
export async function crearReporte(req, res) {
  try {
    const { usuarioReportado, tipoReporte, motivo, descripcion } = req.body;
    const usuarioReportante = req.rut;

    // Validaciones básicas
    if (!usuarioReportado || !tipoReporte || !motivo) {
      return res.status(400).json({
        success: false,
        message: "Faltan campos requeridos: usuarioReportado, tipoReporte, motivo",
      });
    }

    // Verificar que no se reporte a sí mismo
    if (usuarioReportante === usuarioReportado) {
      return res.status(400).json({
        success: false,
        message: "No puedes reportarte a ti mismo",
      });
    }

    // Verificar que el usuario reportado existe
    const userRepository = AppDataSource.getRepository(User);
    const usuarioExiste = await userRepository.findOne({
      where: { rut: usuarioReportado },
    });

    if (!usuarioExiste) {
      return res.status(404).json({
        success: false,
        message: "El usuario a reportar no existe",
      });
    }

    // Verificar si ya existe un reporte similar pendiente
    const reporteRepository = AppDataSource.getRepository(Reporte);
    const reporteExistente = await reporteRepository.findOne({
      where: {
        usuarioReportante,
        usuarioReportado,
        tipoReporte,
        estado: "pendiente",
      },
    });

    if (reporteExistente) {
      return res.status(400).json({
        success: false,
        message: "Ya tienes un reporte pendiente para este usuario en este contexto",
      });
    }

    // Crear el reporte
    const nuevoReporte = reporteRepository.create({
      usuarioReportante,
      usuarioReportado,
      tipoReporte,
      motivo,
      descripcion: descripcion || null,
      estado: "pendiente",
      fechaCreacion: new Date(),
    });

    await reporteRepository.save(nuevoReporte);

    // Incrementar el contador de reportes del usuario reportado
    await userRepository
      .createQueryBuilder()
      .update("User")
      .set({ 
        contadorReportes: () => "contadorReportes + 1",
        updatedAt: new Date()
      })
      .where("rut = :rut", { rut: usuarioReportado })
      .execute();

    console.log(`📝 Nuevo reporte creado: ${usuarioReportante} reportó a ${usuarioReportado} por ${motivo}`);

    res.status(201).json({
      success: true,
      message: "Reporte creado exitosamente",
      data: {
        id: nuevoReporte.id,
        tipoReporte: nuevoReporte.tipoReporte,
        motivo: nuevoReporte.motivo,
        fechaCreacion: nuevoReporte.fechaCreacion,
      },
    });
  } catch (error) {
    console.error("❌ Error al crear reporte:", error);
    res.status(500).json({
      success: false,
      message: "Error interno del servidor",
      error: error.message,
    });
  }
}

// Obtener todos los reportes (solo admin)
export async function obtenerTodosLosReportes(req, res) {
  try {
    const { estado, tipoReporte, usuarioReportado } = req.query;

    const reporteRepository = AppDataSource.getRepository(Reporte);
    let queryBuilder = reporteRepository
      .createQueryBuilder("reporte")
      .leftJoinAndSelect("reporte.reportante", "reportante")
      .leftJoinAndSelect("reporte.reportado", "reportado")
      .leftJoinAndSelect("reporte.revisor", "revisor")
      .orderBy("reporte.fechaCreacion", "DESC");

    // Aplicar filtros
    if (estado) {
      queryBuilder = queryBuilder.andWhere("reporte.estado = :estado", { estado });
    }

    if (tipoReporte) {
      queryBuilder = queryBuilder.andWhere("reporte.tipoReporte = :tipoReporte", { tipoReporte });
    }

    if (usuarioReportado) {
      queryBuilder = queryBuilder.andWhere("reporte.usuarioReportado = :usuarioReportado", { usuarioReportado });
    }

    const reportes = await queryBuilder.getMany();

    res.json({
      success: true,
      data: reportes.map(reporte => ({
        id: reporte.id,
        usuarioReportante: reporte.usuarioReportante,
        usuarioReportado: reporte.usuarioReportado,
        reportante: {
          rut: reporte.reportante?.rut,
          nombreCompleto: reporte.reportante?.nombreCompleto,
        },
        reportado: {
          rut: reporte.reportado?.rut,
          nombreCompleto: reporte.reportado?.nombreCompleto,
        },
        tipoReporte: reporte.tipoReporte,
        motivo: reporte.motivo,
        descripcion: reporte.descripcion,
        estado: reporte.estado,
        fechaCreacion: reporte.fechaCreacion,
        fechaRevision: reporte.fechaRevision,
        adminRevisor: reporte.adminRevisor,
        comentarioAdmin: reporte.comentarioAdmin,
        revisor: reporte.revisor ? {
          rut: reporte.revisor.rut,
          nombreCompleto: reporte.revisor.nombreCompleto,
        } : null,
      })),
    });
  } catch (error) {
    console.error("❌ Error al obtener reportes:", error);
    res.status(500).json({
      success: false,
      message: "Error interno del servidor",
      error: error.message,
    });
  }
}

// Actualizar estado de reporte (solo admin)
export async function actualizarEstadoReporte(req, res) {
  try {
    const { id } = req.params;
    const { estado, comentarioAdmin, enviarNotificacion } = req.body;
    const adminRevisor = req.rut;

    if (!["revisado", "aceptado", "rechazado"].includes(estado)) {
      return res.status(400).json({
        success: false,
        message: "Estado inválido. Debe ser: revisado, aceptado o rechazado",
      });
    }

    const reporteRepository = AppDataSource.getRepository(Reporte);
    const reporte = await reporteRepository.findOne({
      where: { id: parseInt(id) },
      relations: ["reportado"],
    });

    if (!reporte) {
      return res.status(404).json({
        success: false,
        message: "Reporte no encontrado",
      });
    }

    // Actualizar el reporte
    reporte.estado = estado;
    reporte.fechaRevision = new Date();
    reporte.adminRevisor = adminRevisor;
    reporte.comentarioAdmin = comentarioAdmin || null;

    await reporteRepository.save(reporte);

    // Si se acepta el reporte, incrementar contador de reportes del usuario
    if (estado === "aceptado" && reporte.reportado) {
      const userRepository = AppDataSource.getRepository(User);
      await userRepository.increment(
        { rut: reporte.usuarioReportado },
        "contadorReportes",
        1
      );
    }

    // TODO: Enviar notificación si se requiere
    if (enviarNotificacion && estado === "aceptado") {
      // Implementar sistema de notificaciones aquí
      console.log(`📱 Notificación enviada a ${reporte.usuarioReportado} por reporte aceptado`);
    }

    console.log(`✅ Reporte ${id} actualizado a estado: ${estado} por admin: ${adminRevisor}`);

    res.json({
      success: true,
      message: "Reporte actualizado exitosamente",
      data: {
        id: reporte.id,
        estado: reporte.estado,
        fechaRevision: reporte.fechaRevision,
        adminRevisor: reporte.adminRevisor,
      },
    });
  } catch (error) {
    console.error("❌ Error al actualizar reporte:", error);
    res.status(500).json({
      success: false,
      message: "Error interno del servidor",
      error: error.message,
    });
  }
}

// Obtener estadísticas de reportes (solo admin)
export async function obtenerEstadisticasReportes(req, res) {
  try {
    const reporteRepository = AppDataSource.getRepository(Reporte);

    const estadisticas = await Promise.all([
      // Total de reportes
      reporteRepository.count(),
      
      // Reportes por estado
      reporteRepository
        .createQueryBuilder("reporte")
        .select("reporte.estado", "estado")
        .addSelect("COUNT(*)", "cantidad")
        .groupBy("reporte.estado")
        .getRawMany(),
      
      // Reportes por tipo
      reporteRepository
        .createQueryBuilder("reporte")
        .select("reporte.tipoReporte", "tipo")
        .addSelect("COUNT(*)", "cantidad")
        .groupBy("reporte.tipoReporte")
        .getRawMany(),
      
      // Reportes por motivo
      reporteRepository
        .createQueryBuilder("reporte")
        .select("reporte.motivo", "motivo")
        .addSelect("COUNT(*)", "cantidad")
        .groupBy("reporte.motivo")
        .orderBy("COUNT(*)", "DESC")
        .limit(5)
        .getRawMany(),
        
      // Usuarios más reportados (top 10)
      reporteRepository
        .createQueryBuilder("reporte")
        .select("reporte.usuarioReportado", "usuario")
        .addSelect("user.nombreCompleto", "nombre")
        .addSelect("COUNT(*)", "cantidad")
        .leftJoin("reporte.reportado", "user")
        .groupBy("reporte.usuarioReportado")
        .addGroupBy("user.nombreCompleto")
        .orderBy("COUNT(*)", "DESC")
        .limit(10)
        .getRawMany(),
    ]);

    const [total, porEstado, porTipo, porMotivo, usuariosMasReportados] = estadisticas;

    res.json({
      success: true,
      data: {
        total,
        porEstado,
        porTipo,
        porMotivo,
        usuariosMasReportados,
      },
    });
  } catch (error) {
    console.error("❌ Error al obtener estadísticas de reportes:", error);
    res.status(500).json({
      success: false,
      message: "Error interno del servidor",
      error: error.message,
    });
  }
}

// Obtener reportes de un usuario específico (solo admin)
export async function obtenerReportesUsuario(req, res) {
  try {
    const { rutUsuario } = req.params;
    console.log(`🔍 obtenerReportesUsuario - Buscando reportes para usuario: ${rutUsuario}`);
    console.log(`👤 obtenerReportesUsuario - Admin solicitante: ${req.rut}`);

    const reporteRepository = AppDataSource.getRepository(Reporte);
    const reportes = await reporteRepository.find({
      where: { usuarioReportado: rutUsuario },
      relations: ["reportante", "revisor"],
      order: { fechaCreacion: "DESC" },
    });

    console.log(`📊 obtenerReportesUsuario - Reportes encontrados: ${reportes.length}`);

    const userRepository = AppDataSource.getRepository(User);
    const usuario = await userRepository.findOne({
      where: { rut: rutUsuario },
    });

    if (!usuario) {
      console.log(`❌ obtenerReportesUsuario - Usuario no encontrado: ${rutUsuario}`);
      return res.status(404).json({
        success: false,
        message: "Usuario no encontrado",
      });
    }

    console.log(`✅ obtenerReportesUsuario - Usuario encontrado: ${usuario.nombreCompleto}`);

    const response = {
      success: true,
      data: {
        usuario: {
          rut: usuario.rut,
          nombreCompleto: usuario.nombreCompleto,
          contadorReportes: usuario.contadorReportes || 0,
        },
        reportes: reportes.map(reporte => ({
          id: reporte.id,
          reportante: {
            rut: reporte.reportante?.rut,
            nombreCompleto: reporte.reportante?.nombreCompleto,
          },
          tipoReporte: reporte.tipoReporte,
          motivo: reporte.motivo,
          descripcion: reporte.descripcion,
          estado: reporte.estado,
          fechaCreacion: reporte.fechaCreacion,
          fechaRevision: reporte.fechaRevision,
          comentarioAdmin: reporte.comentarioAdmin,
          revisor: reporte.revisor ? {
            rut: reporte.revisor.rut,
            nombreCompleto: reporte.revisor.nombreCompleto,
          } : null,
        })),
      },
    };

    console.log(`✅ obtenerReportesUsuario - Enviando respuesta exitosa`);
    res.json(response);
  } catch (error) {
    console.error("❌ Error al obtener reportes del usuario:", error);
    res.status(500).json({
      success: false,
      message: "Error interno del servidor",
      error: error.message,
    });
  }
}
