import { AppDataSource } from "../config/configDb.js";
import PeticionSupervision from "../entity/peticionSupervision.entity.js";
import User from "../entity/user.entity.js";
import ChatPersonal from "../entity/chatPersonal.entity.js";
import { emitToUser } from "../socket.js";
import { In } from "typeorm";

const peticionSupervisionRepository = AppDataSource.getRepository(PeticionSupervision);
const userRepository = AppDataSource.getRepository(User);
const chatPersonalRepository = AppDataSource.getRepository(ChatPersonal);

/**
 * Crear una nueva petición de supervisión
 * @param {string} rutUsuario - RUT del usuario que solicita supervisión
 * @param {string} motivo - Motivo de la petición
 * @param {string} mensaje - Mensaje del usuario
 * @param {string} prioridad - Prioridad de la petición (baja, media, alta, urgente)
 * @returns {Promise<Object>} Petición creada
 */
export async function crearPeticionSupervision(rutUsuario, motivo, mensaje, prioridad = "media") {
  try {
    // Verificar que el usuario existe
    const usuario = await userRepository.findOne({ where: { rut: rutUsuario } });
    if (!usuario) {
      throw new Error("Usuario no encontrado");
    }

    // Verificar si el usuario ya tiene una petición pendiente o aceptada
    const peticionExistente = await peticionSupervisionRepository.findOne({
      where: { 
        rutUsuario, 
        estado: In(["pendiente", "aceptada"]), 
        eliminado: false 
      },
      relations: ["administrador"],
      order: { fechaCreacion: "DESC" },
    });

    if (peticionExistente) {
      if (peticionExistente.estado === "pendiente") {
        throw new Error("Ya tienes una petición de supervisión pendiente. Por favor espera a que sea respondida antes de crear una nueva.");
      } else if (peticionExistente.estado === "aceptada") {
        const nombreAdmin = peticionExistente.administrador?.nombreCompleto || "un administrador";
        throw new Error(`Ya tienes un chat activo con ${nombreAdmin}. Ve a tu chat para continuar la conversación.`);
      }
    }

    // Crear la petición
    const nuevaPeticion = peticionSupervisionRepository.create({
      rutUsuario,
      nombreUsuario: usuario.nombreCompleto,
      emailUsuario: usuario.email,
      motivo,
      mensaje,
      prioridad,
      estado: "pendiente",
      fechaCreacion: new Date(),
    });

    const peticionGuardada = await peticionSupervisionRepository.save(nuevaPeticion);

    // Notificar a todos los administradores
    await notificarAdministradores(peticionGuardada);

    console.log(`✅ Petición de supervisión creada: ID ${peticionGuardada.id} por usuario ${rutUsuario}`);
    
    return {
      success: true,
      data: peticionGuardada,
      message: "Petición de supervisión enviada exitosamente",
    };

  } catch (error) {
    console.error("Error al crear petición de supervisión:", error.message);
    throw new Error(`Error al crear petición de supervisión: ${error.message}`);
  }
}

/**
 * Obtener todas las peticiones de supervisión (para administradores)
 * @param {string} estado - Filtrar por estado (opcional)
 * @returns {Promise<Array>} Lista de peticiones
 */
export async function obtenerPeticionesSupervision(estado = null) {
  try {
    let query = peticionSupervisionRepository
      .createQueryBuilder("peticion")
      .leftJoinAndSelect("peticion.usuario", "usuario")
      .leftJoinAndSelect("peticion.administrador", "administrador")
      .where("peticion.eliminado = :eliminado", { eliminado: false })
      .orderBy("peticion.fechaCreacion", "DESC");

    if (estado) {
      query = query.andWhere("peticion.estado = :estado", { estado });
    }

    const peticiones = await query.getMany();

    return {
      success: true,
      data: peticiones,
      total: peticiones.length,
    };

  } catch (error) {
    console.error("Error al obtener peticiones de supervisión:", error.message);
    throw new Error(`Error al obtener peticiones: ${error.message}`);
  }
}

/**
 * Responder a una petición de supervisión
 * @param {number} idPeticion - ID de la petición
 * @param {string} rutAdministrador - RUT del administrador que responde
 * @param {string} accion - "aceptar" o "denegar"
 * @param {string} respuesta - Respuesta del administrador (opcional)
 * @returns {Promise<Object>} Petición actualizada
 */
export async function responderPeticionSupervision(idPeticion, rutAdministrador, accion, respuesta = null) {
  try {
    // Verificar que el administrador existe
    const administrador = await userRepository.findOne({ 
      where: { rut: rutAdministrador, rol: "administrador" } 
    });
    
    if (!administrador) {
      throw new Error("Administrador no encontrado o sin permisos");
    }

    // Buscar la petición
    const peticion = await peticionSupervisionRepository.findOne({
      where: { id: idPeticion, eliminado: false },
      relations: ["usuario"],
    });

    if (!peticion) {
      throw new Error("Petición no encontrada");
    }

    if (peticion.estado !== "pendiente") {
      throw new Error("La petición ya ha sido respondida");
    }

    // Actualizar la petición
    const nuevoEstado = accion === "aceptar" ? "aceptada" : "denegada";
    
    await peticionSupervisionRepository.update(idPeticion, {
      estado: nuevoEstado,
      rutAdministrador,
      respuestaAdmin: respuesta,
      fechaRespuesta: new Date(),
    });

    const peticionActualizada = await peticionSupervisionRepository.findOne({
      where: { id: idPeticion },
      relations: ["usuario", "administrador"],
    });

    // Si la petición fue aceptada, crear/asegurar que existe el chat personal
    if (accion === "aceptar") {
      await crearOAsegurarChatPersonal(peticion.rutUsuario, rutAdministrador);
    }

    // Notificar al usuario sobre la respuesta
    await notificarUsuarioRespuesta(peticionActualizada);

    console.log(`✅ Petición ${idPeticion} ${nuevoEstado} por administrador ${rutAdministrador}`);
    
    return {
      success: true,
      data: peticionActualizada,
      message: `Petición ${nuevoEstado} exitosamente`,
    };

  } catch (error) {
    console.error("Error al responder petición de supervisión:", error.message);
    throw new Error(`Error al responder petición: ${error.message}`);
  }
}

/**
 * Obtener peticiones de un usuario específico
 * @param {string} rutUsuario - RUT del usuario
 * @returns {Promise<Array>} Lista de peticiones del usuario
 */
export async function obtenerPeticionesUsuario(rutUsuario) {
  try {
    const peticiones = await peticionSupervisionRepository.find({
      where: { rutUsuario, eliminado: false },
      relations: ["administrador"],
      order: { fechaCreacion: "DESC" },
    });

    return {
      success: true,
      data: peticiones,
    };

  } catch (error) {
    console.error("Error al obtener peticiones del usuario:", error.message);
    throw new Error(`Error al obtener peticiones del usuario: ${error.message}`);
  }
}

/**
 * Eliminar una petición de supervisión
 * @param {number} idPeticion - ID de la petición
 * @param {string} rutUsuario - RUT del usuario (para verificar permisos)
 * @returns {Promise<Object>} Resultado de la eliminación
 */
export async function eliminarPeticionSupervision(idPeticion, rutUsuario) {
  try {
    const peticion = await peticionSupervisionRepository.findOne({
      where: { id: idPeticion, rutUsuario, eliminado: false },
    });

    if (!peticion) {
      throw new Error("Petición no encontrada o no tienes permisos para eliminarla");
    }

    // Soft delete
    await peticionSupervisionRepository.update(idPeticion, {
      eliminado: true,
    });

    console.log(`✅ Petición ${idPeticion} eliminada por usuario ${rutUsuario}`);
    
    return {
      success: true,
      message: "Petición eliminada exitosamente",
    };

  } catch (error) {
    console.error("Error al eliminar petición de supervisión:", error.message);
    throw new Error(`Error al eliminar petición: ${error.message}`);
  }
}

/**
 * Obtener estadísticas de peticiones de supervisión
 * @returns {Promise<Object>} Estadísticas
 */
export async function obtenerEstadisticasPeticiones() {
  try {
    const total = await peticionSupervisionRepository.count({ 
      where: { eliminado: false } 
    });
    
    const pendientes = await peticionSupervisionRepository.count({ 
      where: { estado: "pendiente", eliminado: false } 
    });
    
    const aceptadas = await peticionSupervisionRepository.count({ 
      where: { estado: "aceptada", eliminado: false } 
    });
    
    const denegadas = await peticionSupervisionRepository.count({ 
      where: { estado: "denegada", eliminado: false } 
    });

    // Peticiones por prioridad
    const porPrioridad = await peticionSupervisionRepository
      .createQueryBuilder("peticion")
      .select("peticion.prioridad, COUNT(*) as cantidad")
      .where("peticion.eliminado = :eliminado", { eliminado: false })
      .groupBy("peticion.prioridad")
      .getRawMany();

    return {
      success: true,
      data: {
        total,
        pendientes,
        aceptadas,
        denegadas,
        porPrioridad,
      },
    };

  } catch (error) {
    console.error("Error al obtener estadísticas de peticiones:", error.message);
    throw new Error(`Error al obtener estadísticas: ${error.message}`);
  }
}

/**
 * Notificar a todos los administradores sobre una nueva petición
 * @param {Object} peticion - Petición creada
 */
async function notificarAdministradores(peticion) {
  try {
    // Obtener todos los administradores
    const administradores = await userRepository.find({
      where: { rol: "administrador" },
    });

    console.log(`📢 Encontrados ${administradores.length} administradores para notificar`);

    // Importar servicios necesarios para notificaciones
    const { crearNotificacionService } = await import('./notificacion.service.js');
    const { getSocketInstance } = await import('../socket.js');
    const WebSocketNotificationService = (await import('./push_notification.service.js')).default;

    // Crear notificación del sistema y enviar WebSocket push para cada administrador
    for (const admin of administradores) {
      try {
        // Crear notificación del sistema en la base de datos
        await crearNotificacionService({
          tipo: 'nueva_peticion_soporte',
          titulo: 'Nueva solicitud de soporte',
          mensaje: `${peticion.nombreUsuario} ha enviado una solicitud de chat de soporte`,
          rutReceptor: admin.rut,
          rutEmisor: peticion.rutUsuario,
          datos: {
            peticionId: peticion.id,
            motivo: peticion.motivo,
            prioridad: peticion.prioridad,
            nombreUsuario: peticion.nombreUsuario,
            emailUsuario: peticion.emailUsuario,
            mensaje: peticion.mensaje
          }
        });

        console.log(`✅ Notificación del sistema creada para administrador ${admin.rut}`);
      } catch (notifError) {
        console.error(`❌ Error creando notificación del sistema para admin ${admin.rut}:`, notifError);
      }

      // Enviar notificación WebSocket tradicional (para mantener compatibilidad)
      emitToUser(admin.rut, "nueva_peticion_supervision", {
        id: peticion.id,
        usuario: peticion.nombreUsuario,
        motivo: peticion.motivo,
        prioridad: peticion.prioridad,
        fecha: peticion.fechaCreacion,
        mensaje: "Nueva petición de supervisión recibida",
      });
    }

    // Enviar notificación WebSocket push a todos los administradores
    try {
      const io = getSocketInstance();
      if (io && administradores.length > 0) {
        // Crear array de RUTs de administradores
        const rutesAdministradores = administradores.map(admin => admin.rut);
        
        // Enviar notificación push masiva
        await WebSocketNotificationService.enviarNotificacionSoporteAAdministradores(
          io,
          rutesAdministradores,
          peticion.nombreUsuario,
          peticion.rutUsuario,
          {
            peticionId: peticion.id,
            motivo: peticion.motivo,
            prioridad: peticion.prioridad,
            mensaje: peticion.mensaje,
            fechaCreacion: peticion.fechaCreacion
          }
        );

        console.log(`📱 Notificación WebSocket push enviada a ${administradores.length} administradores`);
      } else {
        console.warn('⚠️ Socket.io no disponible para enviar notificación push');
      }
    } catch (wsError) {
      console.error('❌ Error enviando notificación WebSocket push:', wsError);
    }

    console.log(`📢 Notificación enviada a ${administradores.length} administradores`);

  } catch (error) {
    console.error("Error al notificar administradores:", error.message);
  }
}

/**
 * Notificar al usuario sobre la respuesta a su petición
 * @param {Object} peticion - Petición respondida
 */
async function notificarUsuarioRespuesta(peticion) {
  try {
    const notificacionData = {
      id: peticion.id,
      estado: peticion.estado,
      respuesta: peticion.respuestaAdmin,
      administrador: peticion.administrador?.nombreCompleto,
      rutAdministrador: peticion.rutAdministrador, // Agregar RUT del administrador
      fecha: peticion.fechaRespuesta,
      mensaje: `Tu petición de supervisión ha sido ${peticion.estado}`,
    };

    // Si la petición fue aceptada, incluir información para abrir el chat
    if (peticion.estado === "aceptada") {
      notificacionData.abrirChat = true;
      notificacionData.chatConAdministrador = {
        rutAdministrador: peticion.rutAdministrador,
        nombreAdministrador: peticion.administrador?.nombreCompleto || "Administrador",
      };
    }

    emitToUser(peticion.rutUsuario, "respuesta_peticion_supervision", notificacionData);

    console.log(`📢 Notificación de respuesta enviada al usuario ${peticion.rutUsuario}`);

  } catch (error) {
    console.error("Error al notificar usuario:", error.message);
  }
}

/**
 * Crear o asegurar que existe un chat personal entre usuario y administrador
 * @param {string} rutUsuario - RUT del usuario
 * @param {string} rutAdministrador - RUT del administrador
 * @returns {Promise<Object>} Chat personal creado o existente
 */
async function crearOAsegurarChatPersonal(rutUsuario, rutAdministrador) {
  try {
    // Crear identificador único (menor RUT primero)
    const rutMenor = rutUsuario < rutAdministrador ? rutUsuario : rutAdministrador;
    const rutMayor = rutUsuario < rutAdministrador ? rutAdministrador : rutUsuario;
    const identificadorChat = `${rutMenor}-${rutMayor}`;

    // Buscar chat existente
    let chatPersonal = await chatPersonalRepository.findOne({
      where: { identificadorChat },
      relations: ["usuario1", "usuario2"]
    });

    if (!chatPersonal) {
      // Crear nuevo chat personal
      chatPersonal = chatPersonalRepository.create({
        identificadorChat,
        rutUsuario1: rutMenor,
        rutUsuario2: rutMayor,
        chatCompleto: [],
        ultimoMensaje: null,
        fechaUltimoMensaje: null,
        totalMensajes: 0,
        fechaCreacion: new Date(),
        fechaUltimaActualizacion: new Date(),
        eliminado: false
      });

      await chatPersonalRepository.save(chatPersonal);
      console.log(`✅ Chat personal creado entre ${rutUsuario} y ${rutAdministrador}`);
    } else {
      console.log(`✅ Chat personal ya existe entre ${rutUsuario} y ${rutAdministrador}`);
    }

    return chatPersonal;

  } catch (error) {
    console.error("Error al crear/asegurar chat personal:", error.message);
    throw error;
  }
}

/**
 * Marcar una petición como solucionada
 * @param {number} idPeticion - ID de la petición
 * @param {string} rutAdministrador - RUT del administrador
 * @returns {Promise<Object>} Resultado de la operación
 */
export async function marcarPeticionComoSolucionada(idPeticion, rutAdministrador) {
  try {
    // Verificar que el administrador existe
    const administrador = await userRepository.findOne({ 
      where: { rut: rutAdministrador, rol: "administrador" } 
    });
    
    if (!administrador) {
      throw new Error("Administrador no encontrado o sin permisos");
    }

    // Buscar la petición
    const peticion = await peticionSupervisionRepository.findOne({
      where: { id: idPeticion, eliminado: false },
      relations: ["usuario"],
    });

    if (!peticion) {
      throw new Error("Petición no encontrada");
    }

    if (peticion.estado !== "aceptada") {
      throw new Error("Solo se pueden marcar como solucionadas las peticiones aceptadas");
    }

    // Actualizar la petición
    await peticionSupervisionRepository.update(idPeticion, {
      estado: "solucionada",
      fechaRespuesta: new Date(),
    });

    const peticionActualizada = await peticionSupervisionRepository.findOne({
      where: { id: idPeticion },
      relations: ["usuario", "administrador"],
    });

    // Notificar al usuario sobre la solución
    emitToUser(peticion.rutUsuario, "peticion_solucionada", {
      id: peticion.id,
      mensaje: "Tu petición de supervisión ha sido marcada como solucionada",
      administrador: administrador.nombreCompleto,
    });

    console.log(`✅ Petición ${idPeticion} marcada como solucionada por administrador ${rutAdministrador}`);
    
    return {
      success: true,
      data: peticionActualizada,
      message: "Petición marcada como solucionada exitosamente",
    };

  } catch (error) {
    console.error("Error al marcar petición como solucionada:", error.message);
    throw new Error(`Error al marcar petición como solucionada: ${error.message}`);
  }
}

/**
 * Verificar si un usuario tiene una petición activa (aceptada y no solucionada)
 * @param {string} rutUsuario - RUT del usuario
 * @returns {Promise<Object|null>} Petición activa o null
 */
export async function verificarPeticionActiva(rutUsuario) {
  try {
    const peticionActiva = await peticionSupervisionRepository.findOne({
      where: { 
        rutUsuario, 
        estado: "aceptada", 
        eliminado: false 
      },
      relations: ["administrador"],
      order: { fechaCreacion: "DESC" },
    });

    return peticionActiva;
  } catch (error) {
    console.error("Error al verificar petición activa:", error.message);
    return null;
  }
}

/**
 * Verificar si un usuario tiene una petición pendiente (esperando respuesta del admin)
 * @param {string} rutUsuario - RUT del usuario
 * @returns {Promise<Object|null>} Petición pendiente o null
 */
export async function verificarPeticionPendiente(rutUsuario) {
  try {
    const peticionPendiente = await peticionSupervisionRepository.findOne({
      where: { 
        rutUsuario, 
        estado: "pendiente", 
        eliminado: false 
      },
      relations: ["administrador"],
      order: { fechaCreacion: "DESC" },
    });

    return peticionPendiente;
  } catch (error) {
    console.error("Error al verificar petición pendiente:", error.message);
    return null;
  }
}