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
        
        public K2WorklistDAL()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["DefaultConnString"].ToString();
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

        public void UpdateWorklistSlotStatusByProcInstID(int procInstID)
        {
            WorklistHeader data = new WorklistHeader();
            data = RetrieveWorklistHeaderData(procInstID);
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
        #endregion

    }

    public class WorklistHeader
    {        
        public int HeaderID { get; set; }
        public int ProcInstID { get; set; }
    }
}
