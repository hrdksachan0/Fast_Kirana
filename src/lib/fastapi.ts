/**
 * FastAPI Backend Client
 *
 * Lightweight wrapper around fetch() for calling FastAPI endpoints.
 * Uses NEXT_PUBLIC_API_URL env var.
 *
 * Usage:
 *   import { fastApi } from "@/lib/fastapi";
 *   const data = await fastApi.get("/products");
 *   const user = await fastApi.post("/auth/login", { email, password });
 */

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

export interface FastApiOptions extends Omit<RequestInit, "body"> {
    body?: unknown;
    token?: string;
}

class FastApiClient {
    private baseUrl: string;

    constructor(baseUrl: string) {
        this.baseUrl = baseUrl.replace(/\/$/, "");
    }

    private async request<T = unknown>(
        path: string,
        options: FastApiOptions = {}
    ): Promise<T> {
        const { body, token, headers, ...rest } = options;

        const finalHeaders: Record<string, string> = {
            "Content-Type": "application/json",
            ...(headers as Record<string, string> | undefined),
        };

        if (token) {
            finalHeaders["Authorization"] = `Bearer ${token}`;
        }

        const url = path.startsWith("http")
            ? path
            : `${this.baseUrl}${path.startsWith("/") ? path : `/${path}`}`;

        const response = await fetch(url, {
            ...rest,
            headers: finalHeaders,
            body: body ? JSON.stringify(body) : undefined,
        });

        if (!response.ok) {
            const errorBody = await response.text();
            throw new Error(
                `FastAPI ${response.status}: ${errorBody || response.statusText}`
            );
        }

        // 204 No Content
        if (response.status === 204) {
            return undefined as T;
        }

        return response.json();
    }

    get<T = unknown>(path: string, options?: FastApiOptions) {
        return this.request<T>(path, { ...options, method: "GET" });
    }

    post<T = unknown>(path: string, body?: unknown, options?: FastApiOptions) {
        return this.request<T>(path, { ...options, method: "POST", body });
    }

    patch<T = unknown>(path: string, body?: unknown, options?: FastApiOptions) {
        return this.request<T>(path, { ...options, method: "PATCH", body });
    }

    put<T = unknown>(path: string, body?: unknown, options?: FastApiOptions) {
        return this.request<T>(path, { ...options, method: "PUT", body });
    }

    delete<T = unknown>(path: string, options?: FastApiOptions) {
        return this.request<T>(path, { ...options, method: "DELETE" });
    }
}

export const fastApi = new FastApiClient(API_BASE);

/**
 * Helper: get JWT from NextAuth session
 */
export async function getAuthToken(): Promise<string | null> {
    if (typeof window === "undefined") return null;
    // Token stored by NextAuth after login
    return localStorage.getItem("fastkirana_token") ||
        sessionStorage.getItem("fastkirana_token") ||
        null;
}

export default fastApi;
