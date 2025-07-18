"use strict";
import { EntitySchema } from "typeorm";

const ContactoEmergenciaSchema = new EntitySchema({
  name: "ContactoEmergencia",
  tableName: "contactos_emergencia",
  columns: {
    id: {
      type: "uuid",
      primary: true,
      generated: "uuid",
      nullable: false,
    },
    userRut: {
      type: "varchar",
      length: 12,
      nullable: false,
    },
    nombre: {
      type: "varchar",
      length: 255,
      nullable: false,
    },
    telefono: {
      type: "varchar",
      length: 20,
      nullable: false,
    },
    email: {
      type: "varchar",
      length: 255,
      nullable: true,
    },
    createdAt: {
      type: "timestamp with time zone",
      default: () => "CURRENT_TIMESTAMP",
      nullable: false,
    },
    updatedAt: {
      type: "timestamp with time zone",
      default: () => "CURRENT_TIMESTAMP",
      onUpdate: "CURRENT_TIMESTAMP",
      nullable: false,
    },
  },
  relations: {
    user: {
      type: "many-to-one",
      target: "User",
      joinColumn: {
        name: "userRut",
        referencedColumnName: "rut",
      },
      onDelete: "CASCADE",
    },
  },
  indices: [
    {
      name: "IDX_CONTACTO_EMERGENCIA_USER_RUT",
      columns: ["userRut"],
    },
    {
      name: "IDX_CONTACTO_EMERGENCIA_TELEFONO",
      columns: ["telefono"],
    },
  ],
});

export default ContactoEmergenciaSchema;
