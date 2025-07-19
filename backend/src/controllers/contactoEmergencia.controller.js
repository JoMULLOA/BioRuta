"use strict";
import {
  createContactoEmergenciaService,
  getContactosEmergenciaService,
  updateContactoEmergenciaService,
  deleteContactoEmergenciaService,
} from "../services/contactoEmergencia.service.js";
import {
  contactoEmergenciaBodyValidation,
  contactoEmergenciaQueryValidation,
} from "../validations/contactoEmergencia.validation.js";
import {
  handleErrorClient,
  handleErrorServer,
  handleSuccess,
} from "../handlers/responseHandlers.js";

/**
 * Crear un contacto de emergencia
 */
export async function createContactoEmergencia(req, res) {
  try {
    const { body } = req;
    const userRut = req.user.rut; // Del middleware de autenticación

    const { error } = contactoEmergenciaBodyValidation.validate(body);
    if (error) return handleErrorClient(res, 400, error.message);

    // Verificar que no se excedan los 3 contactos
    const [contactosExistentes] = await getContactosEmergenciaService({ userRut });
    if (contactosExistentes && contactosExistentes.length >= 3) {
      return handleErrorClient(res, 400, "Máximo 3 contactos de emergencia permitidos");
    }

    const contactoData = { ...body, userRut };
    const [contacto, errorContacto] = await createContactoEmergenciaService(contactoData);

    if (errorContacto) return handleErrorClient(res, 400, errorContacto);

    handleSuccess(res, 201, "Contacto de emergencia creado exitosamente", contacto);
  } catch (error) {
    handleErrorServer(res, 500, error.message);
  }
}

/**
 * Obtener contactos de emergencia del usuario
 */
export async function getContactosEmergencia(req, res) {
  try {
    const userRut = req.user.rut;

    const [contactos, errorContactos] = await getContactosEmergenciaService({ userRut });

    if (errorContactos) return handleErrorClient(res, 404, errorContactos);

    contactos.length === 0
      ? handleSuccess(res, 200, "No se encontraron contactos de emergencia", [])
      : handleSuccess(res, 200, "Contactos de emergencia encontrados", contactos);
  } catch (error) {
    handleErrorServer(res, 500, error.message);
  }
}

/**
 * Actualizar un contacto de emergencia
 */
export async function updateContactoEmergencia(req, res) {
  try {
    const { id } = req.params;
    const { body } = req;
    const userRut = req.user.rut;

    const { error } = contactoEmergenciaQueryValidation.validate({ id });
    if (error) return handleErrorClient(res, 400, error.message);

    const { error: bodyError } = contactoEmergenciaBodyValidation.validate(body);
    if (bodyError) return handleErrorClient(res, 400, bodyError.message);

    const [contacto, errorContacto] = await updateContactoEmergenciaService(
      { id, userRut }, 
      body
    );

    if (errorContacto) return handleErrorClient(res, 400, errorContacto);

    handleSuccess(res, 200, "Contacto de emergencia actualizado exitosamente", contacto);
  } catch (error) {
    handleErrorServer(res, 500, error.message);
  }
}

/**
 * Eliminar un contacto de emergencia
 */
export async function deleteContactoEmergencia(req, res) {
  try {
    const { id } = req.params;
    const userRut = req.user.rut;

    const { error } = contactoEmergenciaQueryValidation.validate({ id });
    if (error) return handleErrorClient(res, 400, error.message);

    const [contacto, errorContacto] = await deleteContactoEmergenciaService({ id, userRut });

    if (errorContacto) return handleErrorClient(res, 400, errorContacto);

    handleSuccess(res, 200, "Contacto de emergencia eliminado exitosamente", contacto);
  } catch (error) {
    handleErrorServer(res, 500, error.message);
  }
}
