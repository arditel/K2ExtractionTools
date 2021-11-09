using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Microsoft.Practices.EnterpriseLibrary.Data;
using Microsoft.Practices.EnterpriseLibrary.Data.Sql;
using System.Configuration;
using System.Data.Common;
using System.Data;

namespace K2ExtractionLibrary.DAL
{
    public class K2WorklistDAL
    {
        Database objDB;
        static string _connectionString;
        static string _serverName;
        
        public K2WorklistDAL()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["K2ServerConnString"].ToString();
        }

        private void UpdateWorklistSlotStatus(WorklistHeader worklistHeader)
        {
            objDB = new SqlDatabase(_connectionString);

            string query = "UPDATE [K2Server].[Server].[WorklistSlot] SET Status = 2 WHERE HeaderID = @HeaderID and ProcInstID = @ProcInstID";

            using (DbCommand objCmd = objDB.GetSqlStringCommand(query))
            {
                objDB.AddInParameter(objCmd, "HeaderID", DbType.Int32, worklistHeader.HeaderID);
                objDB.AddInParameter(objCmd, "ProcInstID", DbType.Int32, worklistHeader.ProcInstID);

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

        private WorklistHeader RetrieveWorklistHeaderData(int procInstID)
        {
            IDataReader reader = null;
            WorklistHeader worklistHeader = null;

            objDB = new SqlDatabase(_connectionString);

            string query = "SELECT TOP 1 ID, ProcInstID FROM [K2Server].[Server].[WorklistHeader] where ProcInstID = @ProcInstID";
            
            using (DbCommand objCmd = objDB.GetSqlStringCommand(query))
            {
                objDB.AddInParameter(objCmd,"ProcInstID",DbType.Int32,procInstID);

                try
                {
                    reader = objDB.ExecuteReader(objCmd);
                    worklistHeader = MapWorklistHeader(reader);                    
                }
                catch(Exception ex)
                {
                    throw ex;
                }            
            }
            return worklistHeader;
        }

        private void InsertWorlistSlotLog(WorklistSlotLog worklistSlot)
        {
            objDB = new SqlDatabase(_connectionString);

            using (DbCommand objCmd = objDB.GetStoredProcCommand("General.usp_InsertWorklistSlotLog"))
            {
                objDB.AddInParameter(objCmd, "@ReferenceNo", DbType.String, worklistSlot.ReferenceNo);
                objDB.AddInParameter(objCmd, "@WorkflowStage", DbType.String, worklistSlot.WorkflowStage);
                objDB.AddInParameter(objCmd, "@WorkflowType", DbType.String, worklistSlot.WorkflowType);
                objDB.AddInParameter(objCmd, "@HeaderID", DbType.Int32, worklistSlot.HeaderID);
                objDB.AddInParameter(objCmd, "@ProcInstID", DbType.Int32, worklistSlot.ProcInstID);
                objDB.AddInParameter(objCmd, "@ActInstID", DbType.Int32, worklistSlot.ActInstID);
                objDB.AddInParameter(objCmd, "@SlotFieldID", DbType.Int32, worklistSlot.SlotFieldID);
                objDB.AddInParameter(objCmd, "@EventInstID", DbType.Int32, worklistSlot.EventInstID);
                objDB.AddInParameter(objCmd, "@ActionerID", DbType.Int32, worklistSlot.ActionerID);
                objDB.AddInParameter(objCmd, "@Status", DbType.Int32, worklistSlot.Status);
                objDB.AddInParameter(objCmd, "@Verify", DbType.Boolean, worklistSlot.Verify);
                objDB.AddInParameter(objCmd, "@AllocDate", DbType.DateTime, worklistSlot.AllocDate);

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

        private WorklistSlotLog RetrieveWorklistSlotData(WorklistHeader worklistHeader, string referenceNo, string workflowStage, string workflowType)
        {
            IDataReader reader = null;
            WorklistSlotLog worklistSlot = null;

            objDB = new SqlDatabase(_connectionString);

            string query = "SELECT TOP 1 '" + referenceNo + "' as ReferenceNo,'" + workflowStage + "' as WorkflowStage,'" + workflowType + "' as WorkflowType, " +
                                "HeaderID, ProcInstID, ActInstID, SlotFieldID, EventInstID, ActionerID, Status, Verify, AllocDate " + 
                                "FROM [K2Server].[Server].[WorklistSlot] " + 
                                "WHERE HeaderID = @HeaderID and ProcInstID = @ProcInstID";

            using (DbCommand objCmd = objDB.GetSqlStringCommand(query))
            {
                objDB.AddInParameter(objCmd, "HeaderID", DbType.Int32, worklistHeader.HeaderID);
                objDB.AddInParameter(objCmd, "ProcInstID", DbType.Int32, worklistHeader.ProcInstID);

                try
                {
                    reader = objDB.ExecuteReader(objCmd);
                    worklistSlot = MapWorklistSlotLog(reader);
                }
                catch (Exception ex)
                {
                    throw ex;
                }
            }
            return worklistSlot;
        }

        public void UpdateWorklistSlotStatusByProcInstID(int procInstID, string referenceNo, string workflowStage, string workflowType)
        {
            WorklistHeader data = new WorklistHeader();
            WorklistSlotLog dataWorklistSlotLog = new WorklistSlotLog();

            data = RetrieveWorklistHeaderData(procInstID);

            dataWorklistSlotLog = RetrieveWorklistSlotData(data, referenceNo, workflowStage, workflowType);
            InsertWorlistSlotLog(dataWorklistSlotLog);

            UpdateWorklistSlotStatus(data);
        }

        #region Mapping
        private WorklistHeader MapWorklistHeader(IDataReader reader)
        {
            IList<WorklistHeader> entities = new List<WorklistHeader>();

            while (reader.Read())
            {
                var entity = new WorklistHeader();

                if (!Convert.IsDBNull(reader["ID"]))
                    entity.HeaderID = Convert.ToInt32(reader["ID"].ToString());
                if (!Convert.IsDBNull(reader["ProcInstID"]))
                    entity.ProcInstID = Convert.ToInt32(reader["ProcInstID"].ToString());

                entities.Add(entity);
            }

            return entities.FirstOrDefault();
        }

        private WorklistSlotLog MapWorklistSlotLog(IDataReader reader)
        {
            IList<WorklistSlotLog> entities = new List<WorklistSlotLog>();
            while (reader.Read())
            {
                var entity = new WorklistSlotLog();

                if(!Convert.IsDBNull(reader["ReferenceNo"]))
                    entity.ReferenceNo = reader["ReferenceNo"].ToString();
                if (!Convert.IsDBNull(reader["WorkflowStage"]))
                    entity.WorkflowStage = reader["WorkflowStage"].ToString();
                if (!Convert.IsDBNull(reader["WorkflowType"]))
                    entity.WorkflowType = reader["WorkflowType"].ToString();
                if (!Convert.IsDBNull(reader["HeaderID"]))
                    entity.HeaderID = Convert.ToInt32(reader["HeaderID"].ToString());
                if (!Convert.IsDBNull(reader["ProcInstID"]))
                    entity.ProcInstID = Convert.ToInt32(reader["ProcInstID"].ToString());
                if (!Convert.IsDBNull(reader["ActInstID"]))
                    entity.ActInstID = Convert.ToInt32(reader["ActInstID"].ToString());
                if (!Convert.IsDBNull(reader["SlotFieldID"]))
                    entity.SlotFieldID = Convert.ToInt32(reader["SlotFieldID"].ToString());
                if (!Convert.IsDBNull(reader["EventInstID"]))
                    entity.EventInstID = Convert.ToInt32(reader["EventInstID"].ToString());
                if (!Convert.IsDBNull(reader["ActionerID"]))
                    entity.ActionerID = Convert.ToInt32(reader["ActionerID"].ToString());
                if (!Convert.IsDBNull(reader["Status"]))
                    entity.Status = Convert.ToInt32(reader["Status"].ToString());
                if (!Convert.IsDBNull(reader["Verify"]))
                    entity.Verify = Convert.ToBoolean(reader["Verify"].ToString());
                if (!Convert.IsDBNull(reader["AllocDate"]))
                    entity.AllocDate = Convert.ToDateTime(reader["AllocDate"].ToString());

                entities.Add(entity);
            }

            return entities.FirstOrDefault();
        }
        #endregion

    }

    public class WorklistHeader
    {        
        public int HeaderID { get; set; }
        public int ProcInstID { get; set; }
    }

    public class WorklistSlotLog
    {
        public string ReferenceNo { get; set; }
        public string WorkflowStage { get; set; }
        public string WorkflowType { get; set; }
        public int HeaderID { get; set; }
        public int ProcInstID { get; set; }
        public int ActInstID { get; set; }
        public int SlotFieldID { get; set; }
        public int EventInstID { get; set; }
        public int ActionerID { get; set; }
        public int Status { get; set; }
        public bool Verify { get; set; }
        public DateTime AllocDate { get; set; }
    }
}
