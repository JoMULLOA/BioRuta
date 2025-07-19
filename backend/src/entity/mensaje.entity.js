// src/entity/mensaje.entity.js
import { EntitySchema } from "typeorm";
import User from "./user.entity.js"; // Asegúrate de que esta ruta a tu entidad User sea correcta

export default new EntitySchema({
  name: "Mensaje",
  tableName: "mensajes",
  columns: {
    id: {
      primary: true,
      type: "int",
      generated: true,
    },
    contenido: {
      type: "text",
      nullable: false,
    },
    fecha: {
      type: "timestamp",
      default: () => "CURRENT_TIMESTAMP",
    },
    eliminado: {
      type: "boolean",
      default: false,
    },
    editado: {
      type: "boolean",
      default: false,
    },
    // RUT del emisor del mensaje
    rutEmisor: {
      type: "varchar",
      length: 12,
      nullable: false,
    },
    // RUT del receptor del mensaje (solo para chat 1 a 1)
    rutReceptor: {
      type: "varchar",
      length: 12,
      nullable: true, // Es nulo para mensajes de viaje
    },
    // NUEVA COLUMNA: Para vincular el mensaje a un chat de viaje (MongoDB)
    // Será nulo si el mensaje es para un chat 1 a 1
    idViajeMongo: {
      type: "varchar", // Los IDs de MongoDB (ObjectId) se almacenan como cadenas
      length: 24,      // Un ObjectId tiene 24 caracteres hexadecimales
      nullable: true,  // Es nulo para mensajes 1 a 1, no nulo para mensajes de viaje
    },
  },
  relations: {
    // Relación con el emisor del mensaje (siempre presente)
    emisor: {
      type: "many-to-one",
      target: User,
      joinColumn: {
        name: "rutEmisor",
        referencedColumnName: "rut",

      },
      eager: true, // Cargar el emisor automáticamente al buscar mensajes
    },
    // Relación con el receptor del mensaje (solo para chat 1 a 1)
    // Será nulo si el mensaje es para un chat de viaje
    receptor: {
      type: "many-to-one",
      target: User,
      joinColumn: {
        name: "rutReceptor",
        referencedColumnName: "rut",

      },
      nullable: true, // Es nulo para mensajes de viaje, no nulo para mensajes 1 a 1
      eager: true, // Cargar el receptor automáticamente al buscar mensajes
    },
  },
});
