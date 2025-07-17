"use strict";
import ContactoEmergencia from "../entity/contactoEmergencia.entity.js";
import { AppDataSource } from "../config/configDb.js";

/**
 * Crear un contacto de emergencia
 */
export async function createContactoEmergenciaService(contactoData) {
  try {
    const contactoEmergenciaRepository = AppDataSource.getRepository(ContactoEmergencia);

    // Verificar si ya existe un contacto con el mismo teléfono para este usuario
    const contactoExistente = await contactoEmergenciaRepository.findOne({
      where: { 
        userRut: contactoData.userRut, 
        telefono: contactoData.telefono 
      },
    });

    if (contactoExistente) {
      return [null, "Ya existe un contacto con este número de teléfono"];
    }

    const nuevoContacto = contactoEmergenciaRepository.create(contactoData);
    const contactoCreado = await contactoEmergenciaRepository.save(nuevoContacto);

    return [contactoCreado, null];
  } catch (error) {
    console.error("Error al crear contacto de emergencia:", error);
    return [null, "Error interno del servidor"];
  }
}

/**
 * Obtener contactos de emergencia del usuario
 */
export async function getContactosEmergenciaService(query) {
  try {
    const { userRut } = query;

    const contactoEmergenciaRepository = AppDataSource.getRepository(ContactoEmergencia);

    const contactos = await contactoEmergenciaRepository.find({
      where: { userRut: userRut },
      order: { createdAt: "ASC" },
    });

    return [contactos, null];
  } catch (error) {
    console.error("Error al obtener contactos de emergencia:", error);
    return [null, "Error interno del servidor"];
  }
}

/**
 * Actualizar un contacto de emergencia
 */
export async function updateContactoEmergenciaService(query, contactoData) {
  try {
    const { id, userRut } = query;

    const contactoEmergenciaRepository = AppDataSource.getRepository(ContactoEmergencia);

    const contactoExistente = await contactoEmergenciaRepository.findOne({
      where: { id: id, userRut: userRut },
    });

    if (!contactoExistente) {
      return [null, "Contacto de emergencia no encontrado"];
    }

    // Verificar si el nuevo teléfono ya existe para otro contacto del mismo usuario
    if (contactoData.telefono && contactoData.telefono !== contactoExistente.telefono) {
      const contactoConMismoTelefono = await contactoEmergenciaRepository.findOne({
        where: { 
          userRut: userRut, 
          telefono: contactoData.telefono,
          id: Not(id)
        },
      });

      if (contactoConMismoTelefono) {
        return [null, "Ya existe otro contacto con este número de teléfono"];
      }
    }

    const contactoActualizado = await contactoEmergenciaRepository.save({
      ...contactoExistente,
      ...contactoData,
      updatedAt: new Date(),
    });

    return [contactoActualizado, null];
  } catch (error) {
    console.error("Error al actualizar contacto de emergencia:", error);
    return [null, "Error interno del servidor"];
  }
}

/**
 * Eliminar un contacto de emergencia
 */
export async function deleteContactoEmergenciaService(query) {
  try {
    const { id, userRut } = query;

    const contactoEmergenciaRepository = AppDataSource.getRepository(ContactoEmergencia);

    const contactoExistente = await contactoEmergenciaRepository.findOne({
      where: { id: id, userRut: userRut },
    });

    if (!contactoExistente) {
      return [null, "Contacto de emergencia no encontrado"];
    }

    await contactoEmergenciaRepository.remove(contactoExistente);

    return [contactoExistente, null];
  } catch (error) {
    console.error("Error al eliminar contacto de emergencia:", error);
    return [null, "Error interno del servidor"];
  }
}
