import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  context: vi.fn(),
  redirect: vi.fn(),
  revalidatePath: vi.fn(),
}));

vi.mock("@/lib/auth", () => ({ getCurrentContext: mocks.context }));
vi.mock("@/lib/supabase/server", () => ({ createClient: vi.fn() }));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidatePath }));
vi.mock("next/navigation", () => ({ redirect: mocks.redirect }));

import { createAdvertiser, createCampaign } from "./actions";

const advertiserForm = () => {
  const form = new FormData();
  Object.entries({
    businessName: "Atlas Dental",
    category: "Dental",
    contactName: "Alex Morgan",
    email: "alex@example.com",
    phone: "555-0100",
    addressLine1: "1 Main Street",
    addressLine2: "",
    city: "Wheeling",
    state: "WV",
    postalCode: "26003",
  }).forEach(([key, value]) => form.set(key, value));
  return form;
};

describe("createAdvertiser", () => {
  beforeEach(() => vi.clearAllMocks());

  it("revalidates and redirects after one successful RPC without logging NEXT_REDIRECT", async () => {
    const rpc = vi.fn().mockResolvedValue({ error: null });
    const redirectError = new Error("NEXT_REDIRECT");
    mocks.context.mockResolvedValue({
      supabase: { rpc },
      organizationId: "00000000-0000-4000-8000-000000000001",
      membership: { role: "owner" },
    });
    mocks.redirect.mockImplementation(() => { throw redirectError; });
    const consoleError = vi.spyOn(console, "error").mockImplementation(() => undefined);

    await expect(createAdvertiser({}, advertiserForm())).rejects.toBe(redirectError);

    expect(rpc).toHaveBeenCalledTimes(1);
    expect(mocks.revalidatePath).toHaveBeenCalledWith("/advertisers");
    expect(mocks.redirect).toHaveBeenCalledWith("/advertisers?created=1");
    expect(consoleError).not.toHaveBeenCalled();
    consoleError.mockRestore();
  });

  it("returns a safe state and does not redirect when the RPC fails", async () => {
    const rpc = vi.fn().mockResolvedValue({ error: { code: "23505", message: "constraint secret" } });
    mocks.context.mockResolvedValue({
      supabase: { rpc },
      organizationId: "00000000-0000-4000-8000-000000000001",
      membership: { role: "owner" },
    });
    const consoleError = vi.spyOn(console, "error").mockImplementation(() => undefined);

    await expect(createAdvertiser({}, advertiserForm())).resolves.toEqual({
      message: "An advertiser with that name already exists in this organization.",
    });

    expect(rpc).toHaveBeenCalledTimes(1);
    expect(mocks.revalidatePath).not.toHaveBeenCalled();
    expect(mocks.redirect).not.toHaveBeenCalled();
    consoleError.mockRestore();
  });
});

const validCampaignValues = {
  name: "Spring Mailer", territory: "Ohio Valley", productType: "Postcard",
  publicationDate: "2028-03-05", salesDeadline: "2028-03-01", artworkDeadline: "2028-03-02",
  proofDeadline: "2028-03-03", printDeadline: "2028-03-04", mailingQuantity: "12500",
  estimatedPrintingCost: "1,234.56", estimatedPostageCost: "2500.10", slotCount: "8", standardSlotPrice: "495.00",
};
function campaignForm(overrides: Record<string, string | undefined> = {}, checked = true) {
  const form = new FormData();
  Object.entries({ ...validCampaignValues, ...overrides }).forEach(([key, value]) => { if (value !== undefined) form.set(key, value); });
  if (checked) form.set("categoryExclusivity", "on");
  return form;
}

describe("createCampaign", () => {
  beforeEach(() => { vi.clearAllMocks(); mocks.redirect.mockReset(); });
  function arrangeRpc(data: unknown = "50000000-0000-4000-8000-000000000001") {
    const rpc = vi.fn().mockResolvedValue({ data, error: null });
    mocks.context.mockResolvedValue({ supabase: { rpc }, organizationId: "20000000-0000-4000-8000-000000000001", membership: { role: "owner" } });
    return rpc;
  }

  it.each([[true, true], [false, false]])("maps valid values and checkbox %s into one RPC call", async (checked, expected) => {
    const rpc = arrangeRpc();
    await createCampaign({}, campaignForm({}, checked));
    expect(rpc).toHaveBeenCalledTimes(1);
    expect(rpc).toHaveBeenCalledWith("create_campaign_with_slots", expect.objectContaining({ payload: expect.objectContaining({
      estimated_printing_cost_cents: 123456, estimated_postage_cost_cents: 250010,
      standard_slot_price_cents: 49500, category_exclusivity_enabled: expected,
    }) }));
  });

  it.each([["territory", "Territory is required."], ["productType", "Product type is required."]])("returns a field error and preserves values when %s is missing", async (field, message) => {
    const rpc = arrangeRpc();
    const state = await createCampaign({}, campaignForm({ [field]: undefined }));
    expect(state.errors?.[field]).toContain(message);
    expect(state.values?.name).toBe(validCampaignValues.name);
    expect(state.values?.categoryExclusivity).toBe(true);
    expect(rpc).not.toHaveBeenCalled();
  });

  it.each([
    ["fractional quantity", { mailingQuantity: "1.5" }, "mailingQuantity"],
    ["invalid currency", { standardSlotPrice: "12.345" }, "standardSlotPrice"],
    ["deadline ordering", { proofDeadline: "2028-03-01" }, "proofDeadline"],
  ])("rejects %s without an RPC call", async (_label, override, field) => {
    const rpc = arrangeRpc();
    const state = await createCampaign({}, campaignForm(override));
    expect(state.errors?.[field]).toBeTruthy();
    expect(rpc).not.toHaveBeenCalled();
  });

  it("revalidates and redirects to the authoritative RPC campaign id without swallowing NEXT_REDIRECT", async () => {
    const id = "50000000-0000-4000-8000-000000000099";
    arrangeRpc(id);
    const redirectError = new Error("NEXT_REDIRECT");
    mocks.redirect.mockImplementation(() => { throw redirectError; });
    await expect(createCampaign({}, campaignForm())).rejects.toBe(redirectError);
    expect(mocks.revalidatePath).toHaveBeenCalledWith("/campaigns");
    expect(mocks.redirect).toHaveBeenCalledWith(`/campaigns/${id}`);
  });
});
