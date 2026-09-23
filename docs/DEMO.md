# QuickServe Demo Credentials & Testing Workflow

This guide details pre-configured demo accounts, environment verification, and manual test workflows for testing **QuickServe**.

---

## 1. Demo Credentials

The platform provides pre-configured demo accounts for evaluating each user role:

| Role | Email | Default Password | Initial View |
|---|---|---|---|
| **Customer** | `customer@quickserve.com` | `Password123!` | Customer Dashboard |
| **Agent** | `agent@quickserve.com` | `Password123!` | Agent Dashboard |
| **Admin** | `admin@quickserve.com` | `Password123!` | Admin Portal |

> **Note**: Custom customer or agent accounts can also be created freely via the **Register Account** screen.

---

## 2. Testing End-to-End Workflow

### Step 1: Customer Booking
1. Log in as **Customer** (`customer@quickserve.com`).
2. Click **New Service Request**.
3. Select a category (e.g. `Plumbing`), enter a title, type a service address (or click **Use Live Location**), and submit.
4. The request status is set to `pending` and automated database dispatch initiates.

### Step 2: Agent Offer Acceptance
1. Log in as **Agent** (`agent@quickserve.com`) in a separate browser tab or window.
2. Ensure **Status: Available** is toggled **ON**.
3. The incoming job offer appears under **Incoming Service Offers**.
4. Click **Accept Offer**. The status transitions to `assigned`.

### Step 3: Service Execution & Completion
1. The agent updates status to **Start Service** (`in_progress`).
2. Live GPS location sharing transmits progress to the customer's map view.
3. Upon completion, the agent clicks **Complete Service** (`completed`).
4. Both customer and agent dashboards update in real-time via WebSockets.
