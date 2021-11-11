using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Configuration;
using SourceCode.Workflow.Client;
using SourceCode.Hosting.Client.BaseAPI;
using K2ExtractionLibrary.DAL;
using K2ExtractionLibrary.Model;
using System.Transactions;

namespace K2ExtractionTools
{
    class Program
    {
        private static SCConnectionStringBuilder _connection;
        private static string _connectionString;        
        private static Program _instance;        
        
        private const string PERCENT = "%";
        private const string PREFIX_K2USER = "K2:";
        private const string CLAIMWORKFLOW = "CLAIM";
        private const string POLICYWORKFLOW = "POLICY";

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
            var workflowTypeColl = ConfigurationManager.AppSettings["WorkflowType"].Split(';').ToList();            

            foreach (var _workflowType in workflowTypeColl)
            {
                ProcessK2Data(_workflowType);
            }
        }        

        private static SCConnectionStringBuilder Connection
        {
            get
            {
                /*Debug*/
                return _connection ?? (_connection = new SCConnectionStringBuilder
                {
                    Host = K2ServerName,
                    Port = Convert.ToUInt32(ConfigurationManager.AppSettings["K2Port"]),    
                    UserID = "beyond\\ofh",
                    Password = "ITG@nt1P455QC",
                    IsPrimaryLogin = true,
                    SecurityLabelName = "K2",
                    Integrated = false                        
                }); 
                 
                //return _connection ?? (_connection = new SCConnectionStringBuilder
                //{
                //    Host = K2ServerName,
                //    Port = Convert.ToUInt32(ConfigurationManager.AppSettings["K2Port"]),                        
                //    IsPrimaryLogin = true,
                //    SecurityLabelName = "K2",
                //    Integrated = true                        
                //});              
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

        private static string K2ServerName
        {
            get
            {
                return GetInstance().K2ServerNameFromConfigurationItems();
            }
        }

        #region Non Static Method
        private IList<WorkflowDataActorEntities> GetLastUserFromReferenceNo(string referenceNo, string workflowType)
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

        private void UpdateK2DataStatus(int procInstID, string referenceNo, string workflowStage, string workflowType)
        {
            new K2WorklistDAL().UpdateWorklistSlotStatusByProcInstID(procInstID, referenceNo, workflowStage, workflowType);
        }

        private string K2ServerNameFromConfigurationItems()
        {
            return new WTWorkflowTaskDataDAL().RetrieveK2ServerNameFromConfigurationItems();
        }
        #endregion

        public static void ProcessK2Data(string workflowType)
        {
            int procInstId = 0;
            int countData = Convert.ToInt32(ConfigurationManager.AppSettings["CountDataProcessed"]);

            IList<WorkflowDataProcessedEntities> listData = new List<WorkflowDataProcessedEntities>();
            listData = GetInstance().WorkflowTaskDataProcessed(workflowType).OrderBy(x => x.WTWorkflowTaskDataID).Take(countData).ToList();
                        
            foreach (var item in listData)
            {
                var taskDataList = GetK2TaskDataFromReferenceNo(item.ReferenceNo, workflowType);
                foreach (var data in taskDataList)
                {
                    procInstId = GetInstance().ProcessWTWorkflowTaskDataPIC(data, workflowType);
                    GetK2DataField(data.DataFields,workflowType);
                    GetInstance().UpdateK2DataStatus(procInstId, data.ReferenceNo, data.WorkflowStage, workflowType);
                }
            }      
        }

        public static IList<WTWorkflowTaskDataEntities> GetK2TaskDataFromReferenceNo(string referenceNo, string workflowType)
        {
            IList<WTWorkflowTaskDataEntities> listTaskData = new List<WTWorkflowTaskDataEntities>();
            IList<WorkflowDataActorEntities> listDataActor = new List<WorkflowDataActorEntities>();
            var connection = new Connection();

            WorklistCriteria _worklistCriteria = new WorklistCriteria();
            _worklistCriteria.AddFilterField(WCLogical.AndBracket, WCField.ProcessFolio, WCCompare.Like, string.Concat(PERCENT, referenceNo, PERCENT));

            listDataActor = GetInstance().GetLastUserFromReferenceNo(referenceNo, workflowType);

            foreach (WorkflowDataActorEntities item in listDataActor)
            {
                WTWorkflowTaskDataEntities workflowTaskData = new WTWorkflowTaskDataEntities();
                IList<WTWorkflowDataFieldEntities> dFieldColl = new List<WTWorkflowDataFieldEntities>();
                WTWorkflowDataFieldEntities dataField;

                try
                {
                    connection.Open(K2ServerName, ConnectionString);

                    connection.ImpersonateUser(string.Concat(PREFIX_K2USER, item.Actor));
                    workflowTaskData.Actor = item.Actor;

                    var worklistData = connection.OpenWorklist(_worklistCriteria);
                    var _worklist = (from t in worklistData.OfType<WorklistItem>() select t).ToList<WorklistItem>();

                    foreach (WorklistItem _wlItem in _worklist)
                    {
                        workflowTaskData.SerialNo = _wlItem.SerialNumber;
                        workflowTaskData.ReferenceNo = _wlItem.ProcessInstance.DataFields["ReferenceNo"].Value as string;
                        workflowTaskData.CanvasName = _wlItem.ProcessInstance.Name;
                        workflowTaskData.WorkflowStageCode = _wlItem.ProcessInstance.DataFields["StageCode"].Value as string;
                        workflowTaskData.Folio = _wlItem.ProcessInstance.Folio;
                        workflowTaskData.Originator = _wlItem.ProcessInstance.Originator.Name;
                        workflowTaskData.Status = _wlItem.ProcessInstance.Status1.ToString();
                        workflowTaskData.SubmitDate = _wlItem.ProcessInstance.StartDate;

                        if(workflowType.ToUpper() == CLAIMWORKFLOW)
                            workflowTaskData.WorkflowStage = _wlItem.ProcessInstance.DataFields["Stage"].Value as string;
                        else
                            workflowTaskData.WorkflowStage = _wlItem.ProcessInstance.DataFields["StageCode"].Value as string;

                        if (workflowType.ToUpper() == POLICYWORKFLOW || (workflowType.ToUpper() == CLAIMWORKFLOW && workflowTaskData.WorkflowStage == item.WorkflowStage))
                        {
                            for (int i = 0; i < _wlItem.ProcessInstance.DataFields.Count; i++)
                            {
                                dataField = new WTWorkflowDataFieldEntities();
                                dataField.ReferenceNo = workflowTaskData.ReferenceNo;
                                dataField.SerialNo = workflowTaskData.SerialNo;
                                dataField.CanvasName = workflowTaskData.CanvasName;
                                dataField.WorkflowStageCode = workflowTaskData.WorkflowStageCode;
                                dataField.WOrkflowStageDescription = workflowTaskData.WorkflowStage;
                                dataField.DataFieldName = _wlItem.ProcessInstance.DataFields[i].Name;
                                dataField.DataFieldValue = _wlItem.ProcessInstance.DataFields[i].Value.ToString();

                                dFieldColl.Add(dataField);                          
                            }
                            workflowTaskData.DataFields = dFieldColl.ToList();
                            listTaskData.Add(workflowTaskData);
                        }
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

            return listTaskData;
        }

        public static void GetK2DataField(List<WTWorkflowDataFieldEntities> dataFields, string workflowType)
        {
            WTWorkflowDataFieldEntities dataField;
            foreach (var dField in dataFields)
            {
                dataField = new WTWorkflowDataFieldEntities();
                dataField.ReferenceNo = dField.ReferenceNo;
                dataField.SerialNo = dField.SerialNo;
                dataField.CanvasName = dField.CanvasName;
                dataField.WorkflowStageCode = dField.WorkflowStageCode;
                dataField.WOrkflowStageDescription = dField.WOrkflowStageDescription;
                dataField.DataFieldName = dField.DataFieldName;
                dataField.DataFieldValue = dField.DataFieldValue;

                GetInstance().InsertWTWorkflowDataField(dataField, workflowType);
            }
        }
    }
}
