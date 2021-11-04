using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace K2ExtractionLibrary.Model
{
    public class WTWorkflowTaskDataEntities
    {        
        public string ReferenceNo { get; set; }
        public string SerialNo { get; set; }
        public string CanvasName { get; set; }
        public string WorkflowStageCode { get; set; }
        public string Folio { get; set; }
        public string Originator { get; set; }
        public string Status { get; set; }
        public DateTime SubmitDate { get; set; }
        public string WorkflowStage { get; set; } 
    }
}
