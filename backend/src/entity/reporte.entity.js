import { EntitySchema } from "typeorm";

const Reporte = new EntitySchema({
  name: "Reporte",
  tableName: "reportes",
  columns: {
    id: {
      type: "int",
      primary: true,
      generated: true,
    },
    usuarioReportante: {
      type: "varchar",
      length: 12,
      nullable: false,
    },
    usuarioReportado: {
      type: "varchar", 
      length: 12,
      nullable: false,
    },
    tipoReporte: {
      type: "enum",
      enum: ["ranking", "chatIndividual", "chatGrupal"],
      nullable: false,
    },
    motivo: {
      type: "enum",
      enum: [
        "comportamientoInapropiado",
        "lenguajeOfensivo", 
        "spam",
        "contenidoInadecuado",
        "acoso",
        "fraude",
        "suplantacion",
        "otro"
      ],
      nullable: false,
    },
    descripcion: {
      type: "text",
      nullable: true,
    },
    estado: {
      type: "enum", 
      enum: ["pendiente", "revisado", "aceptado", "rechazado"],
      default: "pendiente",
    },
    fechaCreacion: {
      type: "timestamp",
      default: () => "CURRENT_TIMESTAMP",
    },
    fechaRevision: {
      type: "timestamp",
      nullable: true,
    },
    adminRevisor: {
      type: "varchar",
      length: 12,
      nullable: true,
    },
    comentarioAdmin: {
      type: "text",
      nullable: true,
    },
    notificacionEnviada: {
      type: "boolean",
      default: false,
    },
  },
  relations: {
    reportante: {
      type: "many-to-one",
      target: "User",
      joinColumn: {
        name: "usuarioReportante",
        referencedColumnName: "rut",
      },
      cascade: false,
    },
    reportado: {
      type: "many-to-one", 
      target: "User",
      joinColumn: {
        name: "usuarioReportado",
        referencedColumnName: "rut",
      },
      cascade: false,
    },
    revisor: {
      type: "many-to-one",
      target: "User", 
      joinColumn: {
        name: "adminRevisor",
        referencedColumnName: "rut",
      },
      cascade: false,
      nullable: true,
    },
  },
  indices: [
    {
      name: "IDX_REPORTE_USUARIO_REPORTADO",
      columns: ["usuarioReportado"],
    },
    {
      name: "IDX_REPORTE_ESTADO", 
      columns: ["estado"],
    },
    {
      name: "IDX_REPORTE_TIPO",
      columns: ["tipoReporte"],
    },
    {
      name: "IDX_REPORTE_FECHA",
      columns: ["fechaCreacion"],
    },
  ],
});

export default Reporte;
