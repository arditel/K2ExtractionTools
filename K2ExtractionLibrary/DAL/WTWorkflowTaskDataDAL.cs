﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using K2ExtractionLibrary.Model;
using Microsoft.Practices.EnterpriseLibrary.Data;
using Microsoft.Practices.EnterpriseLibrary.Data.Sql;
using System.Configuration;
using System.Data.Common;
using System.Data;

namespace K2ExtractionLibrary.DAL
{
    public class WTWorkflowTaskDataDAL
    {
        Database objDB;

        static string _connectionString;

        public WTWorkflowTaskDataDAL()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["DefaultConnString"].ToString();
        }

        public string GetLastUserFromReferenceNo(string referenceNo, string nameSpace)
        {
            string result = string.Empty;
            objDB = new SqlDatabase(_connectionString);

            using (DbCommand objCmd = objDB.GetStoredProcCommand("General.usp_GetLastUserFromReferenceNo"))
            {
                objDB.AddInParameter(objCmd, "@ReferenceNo", DbType.String, referenceNo);
                objDB.AddInParameter(objCmd, "@Namespace", DbType.String, nameSpace);
                objDB.AddOutParameter(objCmd, "@UserLogID", DbType.String, 20);

                try
                {
                    objDB.ExecuteNonQuery(objCmd);
                    result = objDB.GetParameterValue(objCmd, "@UserLogID").ToString();
                }
                catch (Exception ex)
                {
                    throw ex;
                }
            }

            return result;
        }        

        public Int32 ProcessWTWorkflowTaskDataPIC(WTWorkflowTaskDataEntities param, string nameSpaceModul)
        {
            Int32 procInstId = 0;
            objDB = new SqlDatabase(_connectionString);

            using (DbCommand objCmd = objDB.GetStoredProcCommand("General.usp_ProcessWTWorkflowTaskDataPIC"))
            {
                objDB.AddInParameter(objCmd, "@ReferenceNo", DbType.String, param.ReferenceNo);
                objDB.AddInParameter(objCmd, "@SerialNo", DbType.String, param.SerialNo);
                objDB.AddInParameter(objCmd, "@CanvasName", DbType.String, param.CanvasName);
                objDB.AddInParameter(objCmd, "@WorkflowStageCode", DbType.String, param.WorkflowStageCode);
                objDB.AddInParameter(objCmd, "@Folio", DbType.String, param.Folio);
                objDB.AddInParameter(objCmd, "@Originator", DbType.String, param.Originator);
                objDB.AddInParameter(objCmd, "@Status", DbType.String, param.Status);
                objDB.AddInParameter(objCmd, "@Namespace", DbType.String, nameSpaceModul);

                try
                {
                    //objDB.ExecuteNonQuery(objCmd);
                    procInstId = Convert.ToInt32(objDB.ExecuteScalar(objCmd));
                }
                catch(Exception ex)
                {
                    throw ex;
                }
            }
            return procInstId;
        }

        public void InsertWTWorkflowDataField(WTWorkflowDataFieldEntities param, string nameSpaceModul)
        {
            objDB = new SqlDatabase(_connectionString);

            using (DbCommand objCmd = objDB.GetStoredProcCommand("General.usp_InsertWTWorkflowDataField"))
            {
                objDB.AddInParameter(objCmd, "@ReferenceNo", DbType.String, param.ReferenceNo);
                objDB.AddInParameter(objCmd, "@DataFieldName", DbType.String, param.DataFieldName);
                objDB.AddInParameter(objCmd, "@DataFIeldValue", DbType.String, param.DataFieldValue);
                objDB.AddInParameter(objCmd, "@Namespace", DbType.String, nameSpaceModul);

                try
                {
                    objDB.ExecuteNonQuery(objCmd);
                }
                catch (Exception ex)
                {
                    throw ex;
                }
            }            
        }

        public IList<WorkflowDataProcessedEntities> WorkflowTaskDataProcessed()
        {
            IDataReader reader = null;
            IList<WorkflowDataProcessedEntities> rows = null;

            objDB = new SqlDatabase(_connectionString);

            using (DbCommand objCmd = objDB.GetStoredProcCommand("General.usp_WorkflowTaskDataProcessed"))
            {
                try
                {
                    reader = objDB.ExecuteReader(objCmd);

                    rows = MapWorkflowDataProcessed(reader);
                }
                catch (Exception ex)
                {
                    throw ex;
                }
            }

            return rows;
        }

        #region Mapping
        private IList<WorkflowDataProcessedEntities> MapWorkflowDataProcessed(IDataReader reader)
        {
            IList<WorkflowDataProcessedEntities> entities = new List<WorkflowDataProcessedEntities>();

            while (reader.Read())
            {
                var entity = new WorkflowDataProcessedEntities();

                if (!Convert.IsDBNull(reader["WTWorkflowTaskDataID"]))
                    entity.WTWorkflowTaskDataID = long.Parse(reader["WTWorkflowTaskDataID"].ToString());
                if (!Convert.IsDBNull(reader["ReferenceNo"]))
                    entity.ReferenceNo = reader["ReferenceNo"].ToString();

                entities.Add(entity);
            }

            return entities;
        }
        #endregion
    }
}
