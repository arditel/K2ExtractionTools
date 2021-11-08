﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Configuration;
using SourceCode.Workflow.Client;
using SourceCode.Hosting.Client.BaseAPI;
using K2ExtractionLibrary.DAL;
using K2ExtractionLibrary.Model;

namespace K2ExtractionTools
{
    class Program
    {
        private static SCConnectionStringBuilder _connection;
        private static string _connectionString;
        private static string _k2User;
        private static Program _instance;
        
        private const string PERCENT = "%";
        private const string PREFIX_K2USER = "K2:";        

        public Program()
        {
        }

        public static Program GetInstance()
        {
            if (_instance == null)
                _instance = new Program();
            return _instance;
        }

        static void Main(string[] args)
        {
            if (args.Length > 0)
            {
                string workflowType = args[0].ToLower();

                LoadConfiguration();
                ProcessK2Data(workflowType);
            }
        }

        private static void LoadConfiguration()
        {
            _k2User = ConfigurationManager.AppSettings["K2User"];
        }

        private static SCConnectionStringBuilder Connection
        {
            get
            {
                return _connection ?? (_connection = new SCConnectionStringBuilder
                {
                    Host = ConfigurationManager.AppSettings["K2ServerAddress"],
                    Port = Convert.ToUInt32(ConfigurationManager.AppSettings["K2Port"]),
                    UserID = _k2User,
                    Password = ConfigurationManager.AppSettings["K2Password"],
                    IsPrimaryLogin = true,
                    SecurityLabelName = "K2",
                    Integrated = false
                });
            }
        }

        private static string ConnectionString
        {
            get
            {
                if (string.IsNullOrEmpty(_connectionString))
                    _connectionString = Connection.ToString();

                return _connectionString;
            }
        }

        #region Non Static Method
        private string GetLastUserFromReferenceNo(string referenceNo, string workflowType)
        {            
            return new WTWorkflowTaskDataDAL().GetLastUserFromReferenceNo(referenceNo,workflowType);
        }        

        private Int32 ProcessWTWorkflowTaskDataPIC(WTWorkflowTaskDataEntities entity, string workflowType)
        {
            return new WTWorkflowTaskDataDAL().ProcessWTWorkflowTaskDataPIC(entity, workflowType);
        }

        private void InsertWTWorkflowDataField(WTWorkflowDataFieldEntities entity, string workflowType)
        {
            new WTWorkflowTaskDataDAL().InsertWTWorkflowDataField(entity, workflowType);
        }

        private IList<WorkflowDataProcessedEntities> WorkflowTaskDataProcessed(string workflowType)
        {
            return new WTWorkflowTaskDataDAL().WorkflowTaskDataProcessed(workflowType);
        }

        private void UpdateK2Data(int procInstID)
        {
            new K2WorklistDAL().UpdateWorklistSlotStatusByProcInstID(procInstID);
        }
        #endregion

        public static void ProcessK2Data(string workflowType)
        {
            int procInstId = 0;
            int countData = Convert.ToInt32(ConfigurationManager.AppSettings["CountDataProcessed"]);

            IList<WorkflowDataProcessedEntities> listData = new List<WorkflowDataProcessedEntities>();
            listData = GetInstance().WorkflowTaskDataProcessed(workflowType).OrderBy(x => x.WTWorkflowTaskDataID).Take(countData).ToList();

            using (System.Transactions.TransactionScope transactionScope = new System.Transactions.TransactionScope())
            {
                try
                {
                    foreach (var item in listData)
                    {
                        var data = GetK2TaskDataFromReferenceNo(item.ReferenceNo, workflowType);
                        procInstId = GetInstance().ProcessWTWorkflowTaskDataPIC(data, workflowType);
                        GetK2DataField(procInstId, item.ReferenceNo, workflowType);
                        GetInstance().UpdateK2Data(procInstId);
                    }
                }
                catch (System.Transactions.TransactionException ex)
                {
                    transactionScope.Dispose();
                    throw ex;
                }
            }
        }

        public static WTWorkflowTaskDataEntities GetK2TaskDataFromReferenceNo(string referenceNo, string workflowType)
        {
            WTWorkflowTaskDataEntities workflowTaskData = new WTWorkflowTaskDataEntities();
            var connection = new Connection();

            WorklistCriteria _worklistCriteria = new WorklistCriteria();
            _worklistCriteria.AddFilterField(WCLogical.AndBracket, WCField.ProcessFolio, WCCompare.Like, string.Concat(PERCENT, referenceNo, PERCENT));

            string userLogID = string.Empty;
            userLogID = GetInstance().GetLastUserFromReferenceNo(referenceNo, workflowType);
            
            try
            {
                connection.Open(ConfigurationManager.AppSettings["K2ServerAddress"], ConnectionString);

                connection.ImpersonateUser(string.Concat(PREFIX_K2USER, userLogID));
                
                var worklistData = connection.OpenWorklist(_worklistCriteria);
                var _worklist = (from t in worklistData.OfType<WorklistItem>() select t).ToList<WorklistItem>().FirstOrDefault();                

                workflowTaskData.SerialNo = _worklist.SerialNumber;
                workflowTaskData.ReferenceNo = _worklist.ProcessInstance.DataFields["ReferenceNo"].Value as string;
                workflowTaskData.CanvasName = _worklist.ProcessInstance.Name;
                workflowTaskData.WorkflowStageCode = _worklist.ProcessInstance.DataFields["StageCode"].Value as string;
                workflowTaskData.Folio = _worklist.ProcessInstance.Folio;
                workflowTaskData.Originator = _worklist.ProcessInstance.Originator.Name;
                workflowTaskData.Status = _worklist.ProcessInstance.Status1.ToString();
                workflowTaskData.SubmitDate = _worklist.ProcessInstance.StartDate;
                workflowTaskData.WorkflowStage = _worklist.ProcessInstance.DataFields["Stage"].Value as string;

                connection.Close();
            }
            catch(Exception ex)
            {
                throw ex;
            }
            finally
            {                
                connection.Close();
                connection.Dispose();
            }

            return workflowTaskData;
        }

        public static void GetK2DataField(int procIntsID, string referenceNo, string workflowType)
        {
            WTWorkflowDataFieldEntities dataField;
            var connection = new Connection();

            try
            {
                connection.Open(ConfigurationManager.AppSettings["K2ServerAddress"],ConnectionString);
                ProcessInstance objProcessInst = connection.OpenProcessInstance(Convert.ToInt32(procIntsID));
                foreach (DataField dField in objProcessInst.DataFields)
                {
                    dataField = new WTWorkflowDataFieldEntities();
                    dataField.ReferenceNo = referenceNo;
                    dataField.DataFieldName = dField.Name;
                    dataField.DataFieldValue = dField.Value.ToString();
                    
                    GetInstance().InsertWTWorkflowDataField(dataField, workflowType);                    
                }
                connection.Close();
            }
            catch (Exception ex)
            {
                throw ex;
            }
            finally
            {
                connection.Close();
                connection.Dispose();
            }            
        }
    }
}
