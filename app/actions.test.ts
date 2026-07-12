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

import { createAdvertiser } from "./actions";

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
