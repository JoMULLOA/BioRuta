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
  },
  relations: {
    emisor: {
      type: "many-to-one",
      target: User,
      joinColumn: { 
        name: "rutEmisor",
        referencedColumnName: "rut",
      },
      eager: true,
    },
    receptor: {
      type: "many-to-one",
      target: User,
      joinColumn: { 
        name: "rutReceptor",
        referencedColumnName: "rut",
      },
      eager: true,
    },
  },
});
