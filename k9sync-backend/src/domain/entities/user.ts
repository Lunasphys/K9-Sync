export interface UserEntity {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  phone: string | null;
  subscriptionPlan: string;
  createdAt: Date;
  updatedAt: Date;
}
