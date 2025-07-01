// src/entity/mensaje.entity.js
import { EntitySchema } from "typeorm";
import User from "./user.entity.js";

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
      default: false,  // Por defecto, el mensaje no está eliminado
    },
    editado: {
      type: "boolean",
      default: false,  // Indica si el mensaje fue editado
    },
  },
  relations: {
    emisor: {
      type: "many-to-one",
      target: User,
      joinColumn: { 
        name: "rutEmisor",
        referencedColumnName: "rut",
        foreignKeyConstraintName: "fk_mensaje_emisor"
      },
      eager: true,
    },
    receptor: {
      type: "many-to-one",
      target: User,
      joinColumn: { 
        name: "rutReceptor",
        referencedColumnName: "rut",
        foreignKeyConstraintName: "fk_mensaje_receptor"
      },
      eager: true,
    },
  },
});
