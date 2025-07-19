import { EntitySchema } from "typeorm";

const PeticionSupervision = new EntitySchema({
  name: "PeticionSupervision",
  tableName: "peticiones_supervision",
  columns: {
    id: {
      primary: true,
      type: "int",
      generated: true,
    },
    rutUsuario: {
      type: "varchar",
      length: 12,
      nullable: false,
    },
    nombreUsuario: {
      type: "varchar",
      length: 255,
      nullable: false,
    },
    emailUsuario: {
      type: "varchar",
      length: 255,
      nullable: false,
    },
    motivo: {
      type: "text",
      nullable: true,
    },
    mensaje: {
      type: "text",
      nullable: false,
    },
    estado: {
      type: "enum",
      enum: ["pendiente", "aceptada", "denegada", "solucionada"],
      default: "pendiente",
    },
    fechaCreacion: {
      type: "timestamp",
      default: () => "CURRENT_TIMESTAMP",
    },
    fechaRespuesta: {
      type: "timestamp",
      nullable: true,
    },
    rutAdministrador: {
      type: "varchar",
      length: 12,
      nullable: true,
    },
    respuestaAdmin: {
      type: "text",
      nullable: true,
    },
    prioridad: {
      type: "enum",
      enum: ["baja", "media", "alta", "urgente"],
      default: "media",
    },
    eliminado: {
      type: "boolean",
      default: false,
    },
  },
  relations: {
    usuario: {
      target: "User",
      type: "many-to-one",
      joinColumn: { name: "rutUsuario", referencedColumnName: "rut" },
    },
    administrador: {
      target: "User",
      type: "many-to-one",
      joinColumn: { name: "rutAdministrador", referencedColumnName: "rut" },
      nullable: true,
    },
  },
});

export default PeticionSupervision;