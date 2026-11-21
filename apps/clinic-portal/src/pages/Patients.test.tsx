// @vitest-environment jsdom
import { describe, expect, it } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import Patients from "./Patients";
import { demoSession } from "../api/client";

describe("Patients page", () => {
  it("lists synthetic patients with today's status", async () => {
    render(<MemoryRouter><Patients session={demoSession()} /></MemoryRouter>);
    await waitFor(() => expect(screen.getByText("Meena")).toBeTruthy());
    expect(screen.getByText("Signed in today")).toBeTruthy();
    expect(screen.getAllByRole("row").length).toBe(13);
  });
});
