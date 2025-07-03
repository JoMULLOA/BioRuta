"use strict";
import { EntitySchema } from "typeorm";

const SolicitudAmistadSchema = new EntitySchema({
  name: "SolicitudAmistad",
  tableName: "solicitudes_amistad",
  columns: {
    id: {
      type: "int",
      primary: true,
      generated: true,
    },
    rutEmisor: {
      type: "varchar",
      length: 12,
      nullable: false,
    },
    rutReceptor: {
      type: "varchar", 
      length: 12,
      nullable: false,
    },
    estado: {
      type: "enum",
      enum: ["pendiente", "aceptada", "rechazada"],
      default: "pendiente",
      nullable: false,
    },
    fechaEnvio: {
      type: "timestamp with time zone",
      default: () => "CURRENT_TIMESTAMP",
      nullable: false,
    },
    fechaRespuesta: {
      type: "timestamp with time zone",
      nullable: true,
    },
    mensaje: {
      type: "text",
      nullable: true,
    },
  },
  relations: {
    emisor: {
      type: "many-to-one",
      target: "User",
      joinColumn: {
        name: "rutEmisor",
        referencedColumnName: "rut",
      },
      eager: true,
    },
    receptor: {
      type: "many-to-one", 
      target: "User",
      joinColumn: {
        name: "rutReceptor",
        referencedColumnName: "rut",
      },
      eager: true,
    },
  },
  indices: [
    {
      name: "IDX_SOLICITUD_EMISOR",
      columns: ["rutEmisor"],
    },
    {
      name: "IDX_SOLICITUD_RECEPTOR", 
      columns: ["rutReceptor"],
    },
    {
      name: "IDX_SOLICITUD_ESTADO",
      columns: ["estado"],
    },
    {
      name: "UNIQUE_SOLICITUD",
      columns: ["rutEmisor", "rutReceptor"],
      unique: true,
    },
  ],
});

export default SolicitudAmistadSchema;
