export interface CampaignHealth {
  id: string;
  name: string;
  territory: string;
  mailDate: string;
  soldSlots: number;
  totalSlots: number;
  collectedAmount: string;
  status: "needs-attention";
}
